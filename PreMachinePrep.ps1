<#
.SYNOPSIS
    Bootstraps a Windows workstation by installing Git + Chocolatey, cloning the MachinePrep repo, and launching it.
.DESCRIPTION
    Self-contained setup script. Handles missing dependencies, reboot warnings, logging, and summary popup.
.PARAMETER TargetPath
    Local folder to clone the repo into. Defaults to current directory.
.PARAMETER ForceReinstall
    Forces reinstall of Chocolatey and Git even if already installed.
.NOTES
    Version: 1.5.0
    Author: oldn3rd
#>

[CmdletBinding()]
param (
    [string]$TargetPath,
    [switch]$ForceReinstall
)

# === Functions ===
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Show-Popup {
    param ([string]$Message, [string]$Title = "PreMachinePrep")
    if ($Host.UI.RawUI.WindowTitle) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', 'Information') | Out-Null
    }
}

function Test-RebootPending {
    $pending = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
    return $null -ne $pending
}

# === Start ===
$StartTime = Get-Date
if (-not $TargetPath) { $TargetPath = (Get-Location).Path }
$LogFile = Join-Path $TargetPath "bootstrap.log"
$RepoUrl = "https://github.com/oldn3rd/MachinePrep.git"
$ScriptPath = Join-Path $TargetPath "MachinePrep.ps1"

Write-Host "PreMachinePrep.ps1 - Version 1.5.0 (Started $($StartTime.ToString("yyyy-MM-dd HH:mm:ss")))"
Write-Host "Target Path: $TargetPath"
"==== PreMachinePrep Log Started at $($StartTime.ToString("yyyy-MM-dd HH:mm:ss")) ====" | Out-File $LogFile

# === Check for reboot pending ===
if (Test-RebootPending) {
    Write-Log "WARNING: System has a pending reboot."
}

# === Chocolatey install ===
$chocoInstalled = Get-Command choco.exe -ErrorAction SilentlyContinue
if (-not $chocoInstalled -or $ForceReinstall) {
    Write-Log "Installing Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "Chocolatey installed successfully."
    } catch {
        Write-Log "ERROR: Chocolatey install failed: $_"
        Show-Popup "Setup failed during Chocolatey installation." "PreMachinePrep"
        exit 10
    }
} else {
    Write-Log "Chocolatey is already installed."
}

# === Git install ===
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
$gitInstalled = Get-Command git.exe -ErrorAction SilentlyContinue
if (-not $gitInstalled -or $ForceReinstall) {
    Write-Log "Installing Git..."
    try {
        choco install git -y --no-progress
        Write-Log "Git installed successfully."
    } catch {
        Write-Log "ERROR: Git install failed: $_"
        Show-Popup "Setup failed during Git installation." "PreMachinePrep"
        exit 11
    }
} else {
    Write-Log "Git is already installed."
}

# === Clone repo ===
try {
    if (-not (Test-Path $TargetPath)) {
        Write-Log "Cloning MachinePrep repo to: $TargetPath"
        git clone $RepoUrl $TargetPath
    } else {
        Write-Log "Repo folder exists. Pulling latest changes..."
        Push-Location $TargetPath
        git pull
        Pop-Location
    }
} catch {
    Write-Log "ERROR: Git clone/pull failed: $_"
    Show-Popup "Failed to pull MachinePrep repo. See bootstrap.log." "PreMachinePrep"
    exit 20
}

# === Launch MachinePrep.ps1 ===
if (Test-Path $ScriptPath) {
    Write-Log "Launching MachinePrep.ps1..."
    try {
        & $ScriptPath
        Write-Log "MachinePrep.ps1 completed."
        Show-Popup "MachinePrep completed successfully." "PreMachinePrep"
        exit 0
    } catch {
        Write-Log "ERROR: Failed to launch MachinePrep.ps1: $_"
        Show-Popup "MachinePrep.ps1 execution failed. See bootstrap.log." "PreMachinePrep"
        exit 30
    }
} else {
    Write-Log "ERROR: MachinePrep.ps1 not found at $ScriptPath"
    Show-Popup "MachinePrep.ps1 not found. Check repo." "PreMachinePrep"
    exit 40
}
