<#
.SYNOPSIS
    Bootstraps a Windows workstation by installing Git and Chocolatey, cloning the MachinePrep repo, and launching it.
.PARAMETER TargetPath
    Folder to clone the repo into (default: current directory\MachinePrep)
.PARAMETER ForceReinstall
    Reinstalls Git/Chocolatey even if already present
.PARAMETER Silent
    Suppresses all output except errors
.PARAMETER NoBanner
    Hides startup banner
.PARAMETER DebugOutput
    Enables extra verbose logging
.NOTES
    Version: 1.8
    Author: oldn3rd
#>

[CmdletBinding()]
param (
    [string]$TargetPath,
    [switch]$ForceReinstall,
    [switch]$Silent,
    [switch]$NoBanner,
    [switch]$DebugOutput
)

# ========== Utility Functions ==========
function Write-Log {
    param ([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"

    $logDir = Split-Path -Path $LogFile -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    Add-Content -Path $LogFile -Value $line

    if (-not $Silent) {
        $color = switch ($Level) {
            "Error"   { "Red" }
            "Warning" { "Yellow" }
            "Debug"   { "Cyan" }
            default   { "Gray" }
        }
        if ($Level -eq "Debug" -and -not $DebugOutput) { return }
        Write-Host $line -ForegroundColor $color
    }
}


function Test-RebootPending {
    Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
}

# ========== Path Setup ==========
if (-not $TargetPath) {
    $TargetPath = (Get-Location).Path
}
$RepoFolder = "MachinePrep"
$RepoPath   = Join-Path $TargetPath $RepoFolder
$ScriptPath = Join-Path $RepoPath "MachinePrep.ps1"
$LogFile    = Join-Path $RepoPath "bootstrap.log"
$GitDir     = Join-Path $RepoPath ".git"
$RepoUrl    = "https://github.com/oldn3rd/MachinePrep.git"

# ========== Startup ==========
if (-not $NoBanner -and -not $Silent) {
    Write-Host "PreMachinePrep.ps1 - Version 1.8"
    Write-Host "Target Path: $RepoPath"
    Write-Host "=========================================="
}
Write-Log "==== PreMachinePrep Started ===="

# ========== Reboot Check ==========
if (Test-RebootPending) {
    Write-Log "System has a pending reboot." "Warning"
}

# ========== Chocolatey ==========
$choco = Get-Command choco.exe -ErrorAction SilentlyContinue
if (-not $choco -or $ForceReinstall) {
    Write-Log "Installing Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "Chocolatey installed successfully."
    } catch {
        Write-Log "Chocolatey install failed: $_" "Error"
        exit 10
    }
} else {
    Write-Log "Chocolatey is already installed."
}

# ========== Git ==========
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine")
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if (-not $git -or $ForceReinstall) {
    Write-Log "Installing Git via Chocolatey..."
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

# ========== Repo Handling ==========
try {
    if (-not (Test-Path $RepoPath)) {
        Write-Log "Cloning MachinePrep to $RepoPath..."
        git clone $RepoUrl $RepoPath
    }
    elseif (-not (Test-Path $GitDir)) {
        Write-Log "Path exists but is not a Git repo." "Warning"
        Write-Log "Removing and re-cloning..."
        Remove-Item -Recurse -Force $RepoPath
        git clone $RepoUrl $RepoPath
    }
    else {
        Write-Log "Pulling latest changes..."
        Push-Location $RepoPath
        git pull
        Pop-Location
    }
} catch {
    Write-Log "Git operation failed: $_" "Error"
    exit 20
}

# ========== Launch MachinePrep.ps1 ==========
if (Test-Path $ScriptPath) {
    Write-Log "Launching MachinePrep.ps1..."
    try {
        & $ScriptPath
        Write-Log "MachinePrep.ps1 executed successfully."
        Write-Log "==== PreMachinePrep Completed ===="
        exit 0
    } catch {
        Write-Log "MachinePrep.ps1 execution failed: $_" "Error"
        exit 30
    }
} else {
    Write-Log "MachinePrep.ps1 not found at: $ScriptPath" "Error"
    exit 40
}
