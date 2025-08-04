<#
.SYNOPSIS
    All-in-one Windows admin workstation prep. Installs tools, modules, CLIs, logs everything. Run from GT or PowerShell Gallery.
.PARAMETER ForceReinstall
    Force reinstall of Git/Choco/Node/AzureCLI/m365 even if detected.
.PARAMETER Silent
    Suppress most console output (still logs to bootstrap.log).
.PARAMETER NoBanner
    Suppress the banner/header output.
.PARAMETER DebugOutput
    Enables verbose log/debug lines.
.NOTES
    Version: 2.0.1
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

$ScriptVersion = '2.0.1'
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
Test-NuGetProvider

Install-ChocoPackage -PackageName "git"
Install-ChocoPackage -PackageName "vscode"
Install-ChocoPackage -PackageName "7zip"


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

# ========== Node.js (for m365 CLI) ==========
if (-not (Get-Command npm -ErrorAction SilentlyContinue) -or $ForceReinstall) {
    Write-Log "Node.js/npm not found or force reinstall. Installing via Chocolatey..."
    try {
        choco install nodejs -y --no-progress
        Write-Log "Node.js installed successfully."
    } catch {
        Write-Log "Node.js install failed: $_" "Error"
    }
} else {
    Write-Log "Node.js/npm already present."
}

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
function Test-NuGetProvider {
    <#
    .SYNOPSIS
        Ensures the NuGet package provider is installed silently.
    .DESCRIPTION
        Checks for the required NuGet provider and installs it if missing.
        Suppresses prompts and uses TLS 1.2 to avoid legacy protocol errors.
    .OUTPUTS
        Writes status to host.
    #>

    Write-Host "[+] Checking NuGet provider..." -ForegroundColor Cyan

    try {
        # Ensure secure connection protocols are enabled
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
    <#
    .SYNOPSIS
        Installs Chocolatey packages quietly; only displays errors or success.
    #>
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


<#
# ========== Microsoft 365 CLI ==========
Write-Log "Checking for Microsoft 365 CLI (m365)..."
if (-not (Get-Command m365 -ErrorAction SilentlyContinue) -or $ForceReinstall) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Log "Installing Microsoft 365 CLI via npm..."
        try {
            npm install -g @pnp/cli-microsoft365
            Write-Log "Microsoft 365 CLI installed."
        } catch {
            Write-Log "Failed to install Microsoft 365 CLI: $_" "Error"
        }
    } else {
        Write-Log "Skipping m365 CLI — npm not found." "Warning"
    }
} else {
    Write-Log "Microsoft 365 CLI already installed."
}
#>
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

