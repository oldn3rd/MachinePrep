<#
.SYNOPSIS
    Bootstraps a fresh Windows workstation by cloning the MachinePrep repo and launching the main setup script.
.DESCRIPTION
    Clones the GitHub repository to a local folder and launches MachinePrep.ps1. Assumes Git is installed.
.PARAMETER TargetPath
    Optional. The folder to clone into. Defaults to the current script directory.
.NOTES
    Author: oldn3rd
    Version: 1.1.0
#>

param(
    [string]$TargetPath = $PSScriptRoot
)

$RepoUrl    = "https://github.com/oldn3rd/MachinePrep.git"
$LocalPath  = $TargetPath
$ScriptPath = Join-Path $LocalPath "MachinePrep.ps1"

Write-Host "=============================================="
Write-Host " PreMachinePrep.ps1 - MachinePrep Bootstrap   "
Write-Host "=============================================="
Write-Host " Target Path: $LocalPath"
Write-Host ""

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "❌ Git is not installed or not in PATH. Please install Git and try again."
        exit 1
    }

    if (-not (Test-Path $LocalPath)) {
        Write-Host "📥 Cloning MachinePrep repo to: $LocalPath..."
        git clone $RepoUrl $LocalPath
    } else {
        Write-Host "🔄 Repo already exists. Pulling latest changes..."
        Push-Location $LocalPath
        git pull
        Pop-Location
    }

    if (Test-Path $ScriptPath) {
        Write-Host "🚀 Launching MachinePrep.ps1..."
        & $ScriptPath
    } else {
        Write-Error "❌ MachinePrep.ps1 not found at: $ScriptPath"
        exit 1
    }
}
catch {
    Write-Error "❌ Setup failed: $_"
    exit 1
}
