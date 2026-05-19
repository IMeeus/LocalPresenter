<#
.SYNOPSIS
    Generates a WAV audio file from a single audio script file.

.PARAMETER ScriptFile
    Path to the audio script .txt file to convert.

.PARAMETER OutputFile
    Path for the output WAV file. Defaults to the same directory and base name
    as the script file (e.g. 05-race-condition.wav alongside 05-race-condition.txt).

.PARAMETER KokoroUrl
    Base URL of the Kokoro-FastAPI server. Overrides the kokoroUrl field in the
    repo-root config.json. Defaults to http://localhost:8880.

.PARAMETER KokoroVoice
    Voice to use. Overrides the kokoroVoice field in the project's config.json.
    Defaults to af_heart.

.EXAMPLE
    .\scripts\Generate-Audio.ps1 -ScriptFile "npoco-caching-issue\slide-audio-scripts\05-race-condition.txt"
#>
param(
    [Parameter(Mandatory)]
    [string]$ScriptFile,

    [string]$OutputFile = "",
    [string]$KokoroUrl  = "",
    [string]$KokoroVoice = ""
)

$ErrorActionPreference = "Stop"

$ScriptFile = Resolve-Path $ScriptFile | Select-Object -ExpandProperty Path
if (-not (Test-Path $ScriptFile)) {
    Write-Error "Script file not found: $ScriptFile"
    exit 1
}

# Default output path: same dir/base as the input file
if (-not $OutputFile) {
    $OutputFile = [System.IO.Path]::ChangeExtension($ScriptFile, ".wav")
}

# --- Resolve KokoroUrl ---
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..") | Select-Object -ExpandProperty Path
$defaultKokoroUrl = "http://localhost:8880"
if (-not $KokoroUrl) {
    $rootConfigFile = Join-Path $repoRoot "config.json"
    if (Test-Path $rootConfigFile) {
        $rootConfig = Get-Content $rootConfigFile -Raw | ConvertFrom-Json
        if ($rootConfig.kokoroUrl) { $KokoroUrl = $rootConfig.kokoroUrl }
    }
    if (-not $KokoroUrl) { $KokoroUrl = $defaultKokoroUrl }
}

# --- Resolve KokoroVoice (project config, then default) ---
if (-not $KokoroVoice) {
    $projectDir = Resolve-Path (Join-Path $ScriptFile "..\..")  -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
    $projectConfigFile = Join-Path $projectDir "config.json"
    if (Test-Path $projectConfigFile) {
        $projectConfig = Get-Content $projectConfigFile -Raw | ConvertFrom-Json
        if ($projectConfig.kokoroVoice) { $KokoroVoice = $projectConfig.kokoroVoice }
    }
    if (-not $KokoroVoice) { $KokoroVoice = "af_heart" }
}

# --- Read and normalize script ---
$scriptText = Get-Content $ScriptFile -Raw -Encoding UTF8
$scriptText = $scriptText -replace '\u2014', ' - '           # em dash —
$scriptText = $scriptText -replace '\u2013', ' - '           # en dash –
$scriptText = $scriptText -replace '[\u201C\u201D]', '"'     # curly double quotes
$scriptText = $scriptText -replace '[\u2018\u2019]', "'"     # curly single quotes

$baseName = [System.IO.Path]::GetFileName($ScriptFile)
Write-Host "[kokoro] $baseName -> $(Split-Path $OutputFile -Leaf)"
Write-Host "         URL: $KokoroUrl  Voice: $KokoroVoice"

$body = @{
    model           = "kokoro"
    input           = $scriptText
    voice           = $KokoroVoice
    response_format = "wav"
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "$KokoroUrl/v1/audio/speech" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body `
    -OutFile $OutputFile

if (-not (Test-Path $OutputFile)) {
    Write-Error "Kokoro failed to produce audio for: $baseName"
    exit 1
}

Write-Host "Done! Audio saved to: $OutputFile"
