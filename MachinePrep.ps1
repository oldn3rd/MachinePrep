<#
.SYNOPSIS
    All-in-one Windows admin workstation prep. Installs tools, modules, CLIs, logs everything.
.PARAMETER ForceReinstall
    Force reinstall of Git/Choco/Node/AzureCLI/m365 even if detected.
.PARAMETER Silent
    Suppress most console output (still logs to bootstrap.log).
.PARAMETER NoBanner
    Suppress the banner/header output.
.PARAMETER DebugOutput
    Enables verbose log/debug lines.
.NOTES
    Version: 2.1.0
    Author: oldn3rd
#>

[CmdletBinding()]
param (
    [switch]$ForceReinstall,
    [switch]$Silent,
    [switch]$NoBanner,
    [switch]$DebugOutput
)

Set-StrictMode -Version Latest

$ScriptVersion = '2.1.0'
$LogFile = Join-Path (Get-Location).Path "bootstrap.log"

# ========== Logging ==========
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

# ========== Banner ==========
if (-not $NoBanner -and -not $Silent) {
    Write-Host "=========================================="
    Write-Host " MachinePrep.ps1 - Version $ScriptVersion"
    Write-Host " (c) 2025 oldn3rd"
    Write-Host "=========================================="
}
Write-Log "==== MachinePrep.ps1 Started (v$ScriptVersion) ===="

# ========== Admin Rights ==========
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Log "Script must be run as Administrator!" "Error"
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    exit 1
}

# ========== Ensure NuGet ==========
Test-NuGetProvider

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

# ========== Install Common Tools ==========
Install-ChocoPackage -PackageName "git"
Install-ChocoPackage -PackageName "vscode"
Install-ChocoPackage -PackageName "7zip"
Install-ChocoPackage -PackageName "nodejs"  # for m365 CLI

# ========== PowerShell Modules ==========
$modules = @(
    @{ Name = "Microsoft.Graph"; Source = "PSGallery" },
    @{ Name = "ExchangeOnlineManagement"; Source = "PSGallery" },
    @{ Name = "AzureAD"; Source = "PSGallery" },
    @{ Name = "MSOnline"; Source = "PSGallery" },
    @{ Name = "Az"; Source = "PSGallery" },
    @{ Name = "MicrosoftTeams"; Source = "PSGallery" },
    @{ Name = "SharePointPnPPowerShellOnline"; Source = "PSGallery" },
    @{ Name = "Defender"; Source = "PSGallery" },
    @{ Name = "Microsoft.Online.SharePoint.PowerShell"; Source = "PSGallery" }
)

Write-Log "Checking and installing/updating required PowerShell modules..."
foreach ($mod in $modules) {
    try {
        $installedModule = Get-Module -ListAvailable -Name $mod.Name | Sort-Object Version -Descending | Select-Object -First 1
        $latestModule = Find-Module -Name $mod.Name -Repository $mod.Source -ErrorAction SilentlyContinue

        if ($null -eq $latestModule) {
            Write-Log "Module '$($mod.Name)' not found in $($mod.Source)" "Warning"
            continue
        }

        if (-not $installedModule) {
            Write-Log "Installing module: $($mod.Name)..."
            Install-Module -Name $mod.Name -Force -AllowClobber -Scope AllUsers -ErrorAction Stop
            Write-Log "Installed $($mod.Name)"
        } elseif ($installedModule.Version -lt $latestModule.Version) {
            Write-Log "Updating module: $($mod.Name) from $($installedModule.Version) to $($latestModule.Version)..."
            Update-Module -Name $mod.Name -Force -ErrorAction Stop
            Write-Log "Updated $($mod.Name)"
        } else {
            Write-Log "Module $($mod.Name) is up-to-date (version $($installedModule.Version))"
        }
    } catch {
        Write-Log "Failed to process module $($mod.Name): $_" "Error"
    }
}

# ========== Azure CLI ==========
Write-Log "Checking for Azure CLI..."
if (-not (Get-Command az -ErrorAction SilentlyContinue) -or $ForceReinstall) {
    Write-Log "Installing Azure CLI..."
    $installer = "$env:TEMP\AzureCLI.msi"
    try {
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile $installer -UseBasicParsing
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$installer`" /quiet"
        Remove-Item $installer -Force
        Write-Log "Azure CLI installed."
    } catch {
        Write-Log "Failed to install Azure CLI: $_" "Error"
    }
} else {
    Write-Log "Azure CLI already installed. Attempting upgrade..."
    try {
        & az upgrade --yes --only-show-errors
        Write-Log "Azure CLI is up-to-date."
    } catch {
        Write-Log "Azure CLI upgrade failed: $_" "Warning"
    }
}

# ========== PowerShell Help ==========
Write-Log "Updating PowerShell Help..."
try {
    Update-Help -Force -ErrorAction Continue
    Write-Log "Help updated successfully."
} catch {
    Write-Log "Help update failed: $_" "Warning"
}

Write-Log "==== MachinePrep.ps1 Completed ===="
Write-Host "All done! See 'bootstrap.log' for details." -ForegroundColor Green
exit 0

# ============================
# SUPPORTING FUNCTIONS BELOW
# ============================

function Test-NuGetProvider {
    Write-Host "[+] Checking NuGet provider..." -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $nuget) {
            Write-Host "[*] NuGet provider not found. Installing..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
            Write-Host "[✓] NuGet provider installed successfully." -ForegroundColor Green
        } else {
            Write-Host "[✓] NuGet provider already installed." -ForegroundColor Green
        }
    } catch {
        Write-Host "[✗] Failed to install NuGet provider: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Install-ChocoPackage {
    param (
        [Parameter(Mandatory)][string]$PackageName
    )

    Write-Host "[+] Installing $PackageName via Chocolatey..." -ForegroundColor Cyan

    $chocoArgs = @(
        "install", $PackageName,
        "--yes",
        "--no-progress",
        "--limit-output"
    )

    try {
        $result = choco @chocoArgs 2>&1 | Where-Object { $_ -match 'error|fail|not found' }

        if ($result) {
            Write-Host "[✗] Error installing $PackageName:" -ForegroundColor Red
            $result | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        } else {
            Write-Host "[✓] $PackageName installed successfully." -ForegroundColor Green
        }
    } catch {
        Write-Host "[✗] Exception during install of $PackageName: $($_.Exception.Message)" -ForegroundColor Red
    }
}
