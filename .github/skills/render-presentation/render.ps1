<#
.SYNOPSIS
    Renders a presenter project into a presentation video.

    Pipeline:
      1. marp   — converts each slides/NN-*.md to a PNG in slide-images/
                  Local images are supported. Mermaid diagrams are pre-rendered
                  to PNG via mmdc before marp runs.
      2. kokoro — converts each slide-audio-scripts/NN-*.txt to WAV in slide-audio/
                  via the Kokoro-FastAPI server (supports [pause:Xs] tags)
      3. ffmpeg — combines each PNG + WAV into a per-slide MP4 segment
      4. ffmpeg — concatenates all segments into output/presentation.mp4 (or presentation-vN.mp4 if one already exists)

.PARAMETER ProjectPath
    Absolute path to the project folder (must contain a 'slides' subfolder).

.PARAMETER KokoroUrl
    Base URL of the Kokoro-FastAPI server. Overrides the kokoroUrl field in the
    repo-root config.json. Defaults to http://localhost:8880.

.EXAMPLE
    .\render.ps1 -ProjectPath "C:\src\projects\presenter\hello-world"
#>
param(
    [Parameter(Mandatory)]
    [string]$ProjectPath,

    [string]$KokoroUrl = ""
)

$ErrorActionPreference = "Stop"

# --- Check required tools ---
foreach ($tool in @("marp", "ffmpeg", "mmdc")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "'$tool' was not found on PATH. Please install it before rendering."
        exit 1
    }
}

# --- Mermaid pre-rendering ---
# Replaces ```mermaid blocks in a slide with PNG images rendered by mmdc.
# Temp files (_tmp_*) are written alongside the original slide so that relative
# image paths in the slide continue to resolve correctly.
# Returns the path to the (possibly new) slide file to pass to marp.
function Get-ProcessedSlidePath {
    param([string]$SlidePath)

    $content = Get-Content $SlidePath -Raw -Encoding UTF8
    if ($content -notmatch '```mermaid') { return $SlidePath }

    $dir  = Split-Path $SlidePath -Parent
    $base = [System.IO.Path]::GetFileNameWithoutExtension($SlidePath)
    $idx  = 0
    $regex = [regex]'(?s)```mermaid\r?\n(.*?)```'

    while ($content -match '(?s)```mermaid\r?\n.*?```') {
        $idx++
        $m       = $regex.Match($content)
        $mmdFile = Join-Path $dir "_tmp_$base-mermaid-$idx.mmd"
        $pngName = "_tmp_$base-mermaid-$idx.png"
        $pngFile = Join-Path $dir $pngName

        [System.IO.File]::WriteAllText($mmdFile, $m.Groups[1].Value, [System.Text.Encoding]::UTF8)
        & mmdc -i $mmdFile -o $pngFile -b white 2>&1 | Write-Verbose
        Remove-Item $mmdFile -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path $pngFile)) {
            Write-Error "mmdc failed to render Mermaid diagram $idx in: $(Split-Path $SlidePath -Leaf)"
            exit 1
        }

        $content = $content.Substring(0, $m.Index) + "![]($pngName)" + $content.Substring($m.Index + $m.Length)
    }

    $tempSlide = Join-Path $dir "_tmp_$base.md"
    [System.IO.File]::WriteAllText($tempSlide, $content, [System.Text.Encoding]::UTF8)
    return $tempSlide
}


# Resolve repo root (script is at .github/skills/render-presentation/render.ps1)
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..") | Select-Object -ExpandProperty Path

# --- Resolve KokoroUrl ---
# Priority: -KokoroUrl param > repo-root config.json > default
$defaultKokoroUrl = "http://localhost:8880"
if (-not $KokoroUrl) {
    $rootConfigFile = Join-Path $repoRoot "config.json"
    if (Test-Path $rootConfigFile) {
        $rootConfig = Get-Content $rootConfigFile -Raw | ConvertFrom-Json
        if ($rootConfig.kokoroUrl) { $KokoroUrl = $rootConfig.kokoroUrl }
    }
    if (-not $KokoroUrl) { $KokoroUrl = $defaultKokoroUrl }
}

# --- Resolve kokoroVoice from project config ---
$kokoroVoice = "af_heart"
$configFile = Join-Path $ProjectPath "config.json"
if (Test-Path $configFile) {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
    if ($config.kokoroVoice) { $kokoroVoice = $config.kokoroVoice }
}

$ProjectPath = Resolve-Path $ProjectPath | Select-Object -ExpandProperty Path

$slidesDir      = Join-Path $ProjectPath "slides"
$scriptsDir     = Join-Path $ProjectPath "slide-audio-scripts"
$imagesDir      = Join-Path $ProjectPath "slide-images"
$audioDir       = Join-Path $ProjectPath "slide-audio"
$outputDir      = Join-Path $ProjectPath "output"

foreach ($dir in @($imagesDir, $audioDir, $outputDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Clear slide-images and slide-audio before rendering
Write-Host "Clearing slide-images and slide-audio ..."
Get-ChildItem -Path $imagesDir | Remove-Item -Force -Recurse
Get-ChildItem -Path $audioDir  | Remove-Item -Force -Recurse
Write-Host ""

$slides = Get-ChildItem -Path $slidesDir -Filter "*.md" |
    Where-Object { $_.Name -notlike "_tmp_*" } |
    Sort-Object Name

if ($slides.Count -eq 0) {
    Write-Error "No .md files found in: $slidesDir"
    exit 1
}

Write-Host "Rendering $($slides.Count) slide(s) in: $ProjectPath"
Write-Host "Kokoro: $KokoroUrl (voice: $kokoroVoice)"
Write-Host ""

$segments = [System.Collections.Generic.List[string]]::new()

try {
foreach ($slide in $slides) {
    $base    = $slide.BaseName
    $imgFile = Join-Path $imagesDir "$base.png"
    $wavFile = Join-Path $audioDir  "$base.wav"
    $segFile = Join-Path $outputDir "segment-$base.mp4"

    # --- 1. marp: markdown -> PNG ---
    Write-Host "[marp]  $($slide.Name) -> slide-images\$base.png"
    $slideToRender = Get-ProcessedSlidePath -SlidePath $slide.FullName
    & marp $slideToRender --image png --allow-local-files --output $imgFile 2>&1 | Write-Verbose
    # Clean up any _tmp_* files created for this slide
    Get-ChildItem -Path $slidesDir -Filter "_tmp_$base*" -ErrorAction SilentlyContinue | Remove-Item -Force
    if (-not (Test-Path $imgFile)) {
        Write-Error "marp failed to produce image for: $($slide.Name)"
        exit 1
    }

    # --- 2. kokoro: text -> WAV ---
    $scriptFile = Join-Path $scriptsDir "$base.txt"
    $hasAudio   = Test-Path $scriptFile
    if ($hasAudio) {
        Write-Host "[kokoro] $base.txt -> slide-audio\$base.wav"
        $scriptText = Get-Content $scriptFile -Raw -Encoding UTF8
        # Normalize Unicode typographic characters.
        $scriptText = $scriptText -replace '\u2014', ' - '   # em dash —
        $scriptText = $scriptText -replace '\u2013', ' - '   # en dash –
        $scriptText = $scriptText -replace '[\u201C\u201D]', '"'  # curly double quotes
        $scriptText = $scriptText -replace '[\u2018\u2019]', "'"  # curly single quotes
        $body = @{
            model           = "kokoro"
            input           = $scriptText
            voice           = $kokoroVoice
            response_format = "wav"
        } | ConvertTo-Json
        Invoke-RestMethod `
            -Uri "$KokoroUrl/v1/audio/speech" `
            -Method Post `
            -ContentType "application/json" `
            -Body $body `
            -OutFile $wavFile
        if (-not (Test-Path $wavFile)) {
            Write-Error "Kokoro failed to produce audio for: $base.txt"
            exit 1
        }
    } else {
        Write-Warning "No audio script for '$base' — slide will be 3 seconds long."
    }

    # --- 3. ffmpeg: PNG + WAV -> segment MP4 ---
    Write-Host "[ffmpeg] Building segment: segment-$base.mp4"
    if ($hasAudio) {
        & ffmpeg -y -loop 1 -i $imgFile -i $wavFile `
            -c:v libx264 -tune stillimage `
            -c:a aac -b:a 192k `
            -pix_fmt yuv420p `
            -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" `
            -shortest `
            $segFile 2>&1 | Write-Verbose
    } else {
        & ffmpeg -y -loop 1 -i $imgFile -t 3 `
            -c:v libx264 -tune stillimage `
            -pix_fmt yuv420p `
            -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" `
            $segFile 2>&1 | Write-Verbose
    }

    if (-not (Test-Path $segFile)) {
        Write-Error "ffmpeg failed to produce segment: $segFile"
        exit 1
    }

    $segments.Add("file '$segFile'")
    Write-Host ""
}

# --- 4. ffmpeg: concatenate segments -> presentation.mp4 ---
$concatFile = Join-Path $outputDir "concat.txt"

# Determine versioned output filename: presentation.mp4, presentation-v1.mp4, presentation-v2.mp4, ...
$presentationFile = Join-Path $outputDir "presentation.mp4"
if (Test-Path $presentationFile) {
    $v = 1
    while (Test-Path (Join-Path $outputDir "presentation-v$v.mp4")) { $v++ }
    $presentationFile = Join-Path $outputDir "presentation-v$v.mp4"
}

$segments | Set-Content $concatFile -Encoding UTF8

Write-Host "[ffmpeg] Concatenating $($segments.Count) segment(s) into $(Split-Path $presentationFile -Leaf) ..."
& ffmpeg -y -f concat -safe 0 -i $concatFile -c copy $presentationFile 2>&1 | Write-Verbose

if (-not (Test-Path $presentationFile)) {
    Write-Error "ffmpeg failed to produce: $presentationFile"
    exit 1
}

# Clean up segment files and concat list
Remove-Item $concatFile -Force
foreach ($line in $segments) {
    $segPath = $line -replace "^file '(.+)'$", '$1'
    if (Test-Path $segPath) { Remove-Item $segPath -Force }
}
} finally {
    # Ensure no _tmp_* files are left in the slides dir (e.g. on error)
    Get-ChildItem -Path $slidesDir -Filter "_tmp_*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host "Done! Video saved to: $presentationFile"
