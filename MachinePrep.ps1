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
    Version: 2.1.2
    Author: oldn3rd (updated with GPT-5 enhancements)
#>

# ================================
# PARAMETERS
# ================================

[CmdletBinding()]
param (
    [switch]$ForceReinstall,
    [switch]$Silent,
    [switch]$NoBanner,
    [switch]$DebugOutput
)

# ================================
# FUNCTIONS
# ================================

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

function Test-NuGetProvider {
    Write-Log "Ensuring NuGet provider is available..."

    $providerUrl = "https://onegetcdn.azureedge.net/providers/Microsoft.PackageManagement.NuGetProvider-2.8.5.208.dll"
    $providerPath = "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208"
    $providerFile = Join-Path $providerPath "Microsoft.PackageManagement.NuGetProvider.dll"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            if (-not (Test-Path $providerFile)) {
                Write-Log "Downloading NuGet provider manually..."
                New-Item -ItemType Directory -Path $providerPath -Force | Out-Null
                Invoke-WebRequest -Uri $providerUrl -OutFile $providerFile -UseBasicParsing
            }
            Import-PackageProvider -Name NuGet -Force
            Write-Log "NuGet provider imported successfully."
        } else {
            Write-Log "NuGet provider already installed."
        }
    } catch {
        Write-Log "NuGet provider install/import failed: $($_.Exception.Message)" "Error"
        throw
    }
}

function Install-ChocoPackage {
    param (
        [Parameter(Mandatory)][string]$PackageName
    )

    Write-Log "Installing package: $PackageName"
    $chocoArgs = @(
        "install", $PackageName,
        "--yes",
        "--no-progress",
        "--limit-output"
    )

    try {
        $result = choco @chocoArgs 2>&1 | Where-Object { $_ -match 'error|fail|not found' }

        if ($result) {
            Write-Log "Error installing $PackageName :`n$result" "Error"
        } else {
            Write-Log "$PackageName installed successfully."
        }
    } catch {
        Write-Log "Exception during install of $PackageName : $($_.Exception.Message)" "Error"
    }
}

function Invoke-WithRetry {
    param (
        [scriptblock]$Script,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 5
    )
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            &$Script
            return
        } catch {
            Write-Log "Attempt $i failed: $($_.Exception.Message)" "Warning"
            if ($i -lt $MaxAttempts) { Start-Sleep -Seconds $DelaySeconds }
            else { throw }
        }
    }
}

Set-StrictMode -Version Latest
$ScriptVersion = '2.1.2'
$LogFile = Join-Path (Get-Location).Path "logs\bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# ================================
# BANNER
# ================================

if (-not $NoBanner -and -not $Silent) {
    Write-Host "=========================================="
    Write-Host " MachinePrep.ps1 - Version $ScriptVersion"
    Write-Host " (c) 2025 oldn3rd"
    Write-Host "=========================================="
}
Write-Log "==== MachinePrep.ps1 Started (v$ScriptVersion) ===="

# ================================
# ADMIN CHECK
# ================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Log "Script must be run as Administrator!" "Error"
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    exit 1
}

# ================================
# REGISTRY CHECK
# ================================
$registryPath = "HKLM:\SOFTWARE\MachinePrep"
$registryName = "SetupComplete"
if (Test-Path $registryPath) {
    $value = Get-ItemProperty -Path $registryPath -Name $registryName -ErrorAction SilentlyContinue
    if ($value -and $value.$registryName -eq "Yes") {
        Write-Log "MachinePrep has already been run on this system. Skipping redundant steps..." "Info"
    }
} else {
    New-Item -Path $registryPath -Force | Out-Null
}

# ================================
# MAIN SCRIPT EXECUTION
# ================================

Test-NuGetProvider

# Chocolatey install (with retry)
$choco = Get-Command choco.exe -ErrorAction SilentlyContinue
if (-not $choco -or $ForceReinstall) {
    Write-Log "Installing Chocolatey..."
    Invoke-WithRetry {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    Write-Log "Chocolatey installed successfully."
} else {
    Write-Log "Chocolatey is already installed."
}

# Package installs
$packages = @("git", "vscode", "7zip", "nodejs", "powershell")
foreach ($pkg in $packages) {
    Invoke-WithRetry { Install-ChocoPackage -PackageName $pkg }
}

# PowerShell Modules
$modules = @(
    @{ Name = "Microsoft.Graph" },
    @{ Name = "ExchangeOnlineManagement" },
    @{ Name = "AzureAD" },
    @{ Name = "MSOnline" },
    @{ Name = "Az" },
    @{ Name = "MicrosoftTeams" },
    @{ Name = "SharePointPnPPowerShellOnline" },
    @{ Name = "Defender" },
    @{ Name = "Microsoft.Online.SharePoint.PowerShell" }
)

Write-Log "Checking and installing/updating required PowerShell modules..."
foreach ($mod in $modules) {
    try {
        $installedModule = Get-Module -ListAvailable -Name $mod.Name | Sort-Object Version -Descending | Select-Object -First 1
        $latestModule = Find-Module -Name $mod.Name -Repository PSGallery -ErrorAction SilentlyContinue

        if (-not $latestModule) {
            Write-Log "Module '$($mod.Name)' not found in PSGallery" "Warning"
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

# Azure CLI
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

# Help
Write-Log "Updating PowerShell Help..."
try {
    Update-Help -Force -ErrorAction Continue
    Write-Log "Help updated successfully."
} catch {
    Write-Log "Help update failed: $_" "Warning"
}

# ================================
# WRITE REGISTRY MARKER
# ================================
Set-ItemProperty -Path $registryPath -Name $registryName -Value "Yes"

Write-Log "==== MachinePrep.ps1 Completed ===="
Write-Host "All done! See 'logs' folder for details." -ForegroundColor Green
exit 0
