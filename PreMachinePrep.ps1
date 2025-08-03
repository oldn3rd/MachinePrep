<#
.SYNOPSIS
    Bootstraps a workstation: installs Git + Chocolatey, clones the MachinePrep repo, launches it.
.PARAMETER TargetPath
    Folder to clone into. Defaults to current directory.
.PARAMETER ForceReinstall
    Reinstalls Git and Chocolatey even if present.
.PARAMETER Silent
    Suppresses all Write-Host output.
.PARAMETER NoBanner
    Suppresses the startup header only.
.NOTES
    Version: 1.6
    Author: oldn3rd
#>

[CmdletBinding()]
param (
    [string]$TargetPath,
    [switch]$ForceReinstall,
    [switch]$Silent,
    [switch]$NoBanner
)

function Write-Log {
    param ([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    if (-not $Silent) {
        $color = switch ($Level) {
            "Error"   { "Red" }
            "Warning" { "Yellow" }
            default   { "Gray" }
        }
        Write-Host $line -ForegroundColor $color
    }
}

function Test-RebootPending {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    return Test-Path $key
}

# === Defaults ===
if (-not $TargetPath) { $TargetPath = (Get-Location).Path }
$RepoUrl = "https://github.com/oldn3rd/MachinePrep.git"
$ScriptPath = Join-Path $TargetPath "MachinePrep.ps1"
$LogFile = Join-Path $TargetPath "bootstrap.log"

# === Startup Banner ===
if (-not $NoBanner -and -not $Silent) {
    $ver = "1.6"
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "PreMachinePrep.ps1 - Version $ver (Started $now)"
    Write-Host "Target Path: $TargetPath"
    Write-Host "=============================================="
}
Write-Log "==== PreMachinePrep Start ===="

# === Reboot check ===
if (Test-RebootPending) {
    Write-Log "System has a pending reboot." "Warning"
}

# === Chocolatey ===
$chocoInstalled = Get-Command choco.exe -ErrorAction SilentlyContinue
if (-not $chocoInstalled -or $ForceReinstall) {
    Write-Log "Installing Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "Chocolatey installed successfully."
    } catch {
        Write-Log "Chocolatey install failed: $_" "Error"
        exit 10
    }
} else {
    Write-Log "Chocolatey is already installed."
}

# === Git ===
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
$gitInstalled = Get-Command git.exe -ErrorAction SilentlyContinue
if (-not $gitInstalled -or $ForceReinstall) {
    Write-Log "Installing Git..."
    try {
        choco install git -y --no-progress
        Write-Log "Git installed successfully."
    } catch {
        Write-Log "Git install failed: $_" "Error"
        exit 11
    }
} else {
    Write-Log "Git is already installed."
}

# === Repo check ===
$existingPath = Test-Path $TargetPath
$gitDir = Join-Path $TargetPath ".git"

try {
    if (-not $existingPath) {
        Write-Log "Cloning repo to: $TargetPath"
        git clone $RepoUrl $TargetPath
    }
    elseif (-not (Test-Path $gitDir)) {
        Write-Log "Target path exists but is not a Git repo." "Warning"
        Write-Log "Removing folder and re-cloning..."
        Remove-Item -Recurse -Force -Path $TargetPath
        git clone $RepoUrl $TargetPath
    }
    else {
        Write-Log "Repo folder exists. Pulling latest changes..."
        Push-Location $TargetPath
        git pull
        Pop-Location
    }
}
catch {
    Write-Log "Git clone/pull failed: $_" "Error"
    exit 20
}

# === Run main script ===
if (Test-Path $ScriptPath) {
    Write-Log "Launching MachinePrep.ps1..."
    try {
        & $ScriptPath
        Write-Log "MachinePrep.ps1 executed successfully."
        Write-Log "==== PreMachinePrep Completed ===="
        exit 0
    } catch {
        Write-Log "MachinePrep.ps1 failed: $_" "Error"
        exit 30
    }
} else {
    Write-Log "MachinePrep.ps1 not found at $ScriptPath" "Error"
    exit 40
}
