<#
.SYNOPSIS
    Renders a presenter project into a presentation video.

    Pipeline:
      1. marp   — converts each slides/NN-*.md to a PNG in slide-images/
      2. kokoro — converts each slide-audio-scripts/NN-*.txt to WAV in slide-audio/
                  via the Kokoro-FastAPI server (supports [pause:Xs] tags)
      3. ffmpeg — combines each PNG + WAV into a per-slide MP4 segment
      4. ffmpeg — concatenates all segments into output/presentation.mp4

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

$slides = Get-ChildItem -Path $slidesDir -Filter "*.md" | Sort-Object Name

if ($slides.Count -eq 0) {
    Write-Error "No .md files found in: $slidesDir"
    exit 1
}

Write-Host "Rendering $($slides.Count) slide(s) in: $ProjectPath"
Write-Host "Kokoro: $KokoroUrl (voice: $kokoroVoice)"
Write-Host ""

$segments = [System.Collections.Generic.List[string]]::new()

foreach ($slide in $slides) {
    $base    = $slide.BaseName
    $imgFile = Join-Path $imagesDir "$base.png"
    $wavFile = Join-Path $audioDir  "$base.wav"
    $segFile = Join-Path $outputDir "segment-$base.mp4"

    # --- 1. marp: markdown -> PNG ---
    Write-Host "[marp]  $($slide.Name) -> slide-images\$base.png"
    & marp $slide.FullName --image png --output $imgFile 2>&1 | Write-Verbose
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
$concatFile       = Join-Path $outputDir "concat.txt"
$presentationFile = Join-Path $outputDir "presentation.mp4"

$segments | Set-Content $concatFile -Encoding UTF8

Write-Host "[ffmpeg] Concatenating $($segments.Count) segment(s) into presentation.mp4 ..."
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

Write-Host "Done! Video saved to: $presentationFile"
