<#
.SYNOPSIS
    Renders a presenter project into a presentation video.

    Pipeline:
      1. marp  — converts each slides/NN-*.md to a PNG in slide-images/
      2. piper — converts each slide-audio-scripts/NN-*.txt to WAV in slide-audio/
      3. ffmpeg — combines each PNG + WAV into a per-slide MP4 segment
      4. ffmpeg — concatenates all segments into output/presentation.mp4

.PARAMETER ProjectPath
    Absolute path to the project folder (must contain a 'slides' subfolder).

.PARAMETER ModelPath
    Path to the piper ONNX voice model. Defaults to the model specified in the project's
    config.json (voiceModel field), falling back to .piper\models\en_US-lessac-medium.onnx
    relative to the repository root (two levels above this script's location).

.EXAMPLE
    .\render.ps1 -ProjectPath "C:\src\projects\presenter\hello-world"
#>
param(
    [Parameter(Mandatory)]
    [string]$ProjectPath,

    [string]$ModelPath = ""
)

$ErrorActionPreference = "Stop"

# Resolve repo root (script is at .github/skills/render-presentation/render.ps1)
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..") | Select-Object -ExpandProperty Path

if (-not $ModelPath) {
    $defaultModel = "en_US-lessac-medium"
    $configFile = Join-Path $ProjectPath "config.json"
    if (Test-Path $configFile) {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($config.voiceModel) { $defaultModel = $config.voiceModel }
    }
    $ModelPath = Join-Path $repoRoot ".piper\models\$defaultModel.onnx"
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

if (-not (Test-Path $ModelPath)) {
    Write-Error "Piper model not found at: $ModelPath"
    exit 1
}

$slides = Get-ChildItem -Path $slidesDir -Filter "*.md" | Sort-Object Name

if ($slides.Count -eq 0) {
    Write-Error "No .md files found in: $slidesDir"
    exit 1
}

Write-Host "Rendering $($slides.Count) slide(s) in: $ProjectPath"
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

    # --- 2. piper: text -> WAV ---
    $scriptFile = Join-Path $scriptsDir "$base.txt"
    $hasAudio   = Test-Path $scriptFile
    if ($hasAudio) {
        Write-Host "[piper] $base.txt -> slide-audio\$base.wav"
        Get-Content $scriptFile -Raw |
            & piper --model $ModelPath --output_file $wavFile
        if (-not (Test-Path $wavFile)) {
            Write-Error "piper failed to produce audio for: $base.txt"
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
