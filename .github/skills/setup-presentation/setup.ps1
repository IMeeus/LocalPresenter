<#
.SYNOPSIS
    Scaffolds a new presentation project folder structure.

.PARAMETER ProjectName
    The name of the new project (lowercase, hyphens for spaces).

.PARAMETER RepoRoot
    The root of the presenter repository. Defaults to the current directory.

.EXAMPLE
    .\setup.ps1 -ProjectName "my-talk" -RepoRoot "C:\src\projects\presenter"
#>
param(
    [Parameter(Mandatory)]
    [string]$ProjectName,

    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$projectPath = Join-Path $RepoRoot $ProjectName

if (Test-Path $projectPath) {
    Write-Warning "Project folder '$projectPath' already exists. Skipping creation."
} else {
    $folders = @(
        "slides",
        "slide-audio-scripts",
        "slide-audio",
        "slide-images",
        "output"
    )
    foreach ($folder in $folders) {
        New-Item -ItemType Directory -Path (Join-Path $projectPath $folder) -Force | Out-Null
    }
    Write-Host "Created project folder: $projectPath"
}

$placeholderSlide = Join-Path $projectPath "slides\01-title.md"
if (-not (Test-Path $placeholderSlide)) {
    @"
---
marp: true
theme: default
---

# $ProjectName

Your first slide. Replace this with your content.
"@ | Set-Content $placeholderSlide -Encoding UTF8
    Write-Host "Created placeholder slide: slides\01-title.md"
}

$placeholderScript = Join-Path $projectPath "slide-audio-scripts\01-title.txt"
if (-not (Test-Path $placeholderScript)) {
    "Welcome to $ProjectName. Replace this with your narration script." |
        Set-Content $placeholderScript -Encoding UTF8
    Write-Host "Created placeholder audio script: slide-audio-scripts\01-title.txt"
}

Write-Host ""
Write-Host "Project '$ProjectName' is ready at: $projectPath"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit slides in:         $projectPath\slides\"
Write-Host "  2. Edit audio scripts in:  $projectPath\slide-audio-scripts\"
Write-Host "  3. Run render-presentation to generate the video"
