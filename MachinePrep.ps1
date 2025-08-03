<#
.SYNOPSIS
    Prepares a Windows admin workstation with required tools, PowerShell modules, and CLIs.

.VERSION
    1.0.0

.DESCRIPTION
    This script installs essential tools via Chocolatey, key PowerShell modules for Microsoft 365 and Azure, and configures the local environment for admin use.
#>

$ScriptVersion = '1.0.0'
Write-Host "==========================================="
Write-Host "MachinePrep.ps1 - Version $ScriptVersion"
Write-Host "==========================================="

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Warning "Please run this script as Administrator!"
    exit 1
}

Write-Host " Checking internet connectivity..."
try {
    Invoke-WebRequest -Uri "https://www.bing.com" -UseBasicParsing -TimeoutSec 10 | Out-Null
} catch {
    Write-Warning "No internet connectivity. Please connect and rerun."
    exit 1
}

Write-Host " Detecting operating system..."
$osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
$isServer = $osCaption -like '*Server*'

# Ensure NuGet provider is available
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host " Installing NuGet provider..."
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers
}

# ========== RSAT INSTALLATION ==========
if ($isServer) {
    Write-Host "Detected Windows Server — using Add-WindowsFeature..."
    try {
        if (-not (Get-WindowsFeature GPMC).Installed) {
            Install-WindowsFeature GPMC -ErrorAction Stop
            Write-Host "Installed GPMC"
        } else {
            Write-Host "GPMC already installed"
        }
        if (-not (Get-WindowsFeature RSAT-AD-PowerShell).Installed) {
            Install-WindowsFeature RSAT-AD-PowerShell -ErrorAction Stop
            Write-Host "Installed RSAT AD Tools"
        } else {
            Write-Host "RSAT AD Tools already installed"
        }
    } catch {
        Write-Warning ("Failed to install server features: {0}" -f $_)
    }
} else {
    Write-Host "Detected Windows Client — using Add-WindowsCapability..."
    $rsatFeatures = @(
        "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0",
        "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0"
    )
    foreach ($feature in $rsatFeatures) {
        try {
            $cap = Get-WindowsCapability -Online -Name $feature
            if ($cap.State -ne 'Installed') {
                Write-Host " Installing RSAT Feature: $feature..."
                Add-WindowsCapability -Online -Name $feature -ErrorAction Stop
                Write-Host "Installed $feature"
            } else {
                Write-Host "RSAT Feature already installed: $feature"
            }
        } catch {
            Write-Warning ("Failed to install RSAT Feature {0}: {1}" -f $feature, $_)
        }
    }
}

# ========== PowerShell Module Install/Update ==========
$modules = @(
    @{ Name = "Microsoft.Graph"; Source = "PSGallery" },
    @{ Name = "ExchangeOnlineManagement"; Source = "PSGallery" },
    @{ Name = "AzureAD"; Source = "PSGallery" },
    @{ Name = "MSOnline"; Source = "PSGallery" },
    @{ Name = "Az"; Source = "PSGallery" },
    @{ Name = "MicrosoftTeams"; Source = "PSGallery" },
    @{ Name = "SharePointPnPPowerShellOnline"; Source = "PSGallery" },
    @{ Name = "Defender"; Source = "PSGallery" },
    @{ Name = "Microsoft.Online.SharePoint.PowerShell"; Source = "PSGallery" },
    @{ Name = "SharePointOnline"; Source = "PSGallery" },
    @{ Name = "Teams"; Source = "PSGallery" }
)

Write-Host " Checking and installing/updating required PowerShell modules..."
foreach ($mod in $modules) {
    $installedModule = Get-Module -ListAvailable -Name $mod.Name | Sort-Object Version -Descending | Select-Object -First 1
    $latestModule = Find-Module -Name $mod.Name -Repository $mod.Source -ErrorAction SilentlyContinue

    if ($null -eq $installedModule) {
        Write-Host " Installing module: $($mod.Name)..."
        try {
            Install-Module -Name $mod.Name -Force -AllowClobber -Scope AllUsers -ErrorAction Stop
            Write-Host "Installed $($mod.Name)"
        } catch {
            Write-Warning ("Failed to install {0}: {1}" -f $mod.Name, $_)
        }
    } elseif ($null -ne $latestModule -and $installedModule.Version -lt $latestModule.Version) {
        Write-Host ("⬆️  Updating module: {0} from {1} to {2}..." -f $mod.Name, $installedModule.Version, $latestModule.Version)
        try {
            Update-Module -Name $mod.Name -Force -ErrorAction Stop
            Write-Host "Updated $($mod.Name)"
        } catch {
            Write-Warning ("Failed to update {0}: {1}" -f $mod.Name, $_)
        }
    } else {
        Write-Host ("Module {0} is up-to-date (version {1})" -f $mod.Name, $installedModule.Version)
    }
}

# ========== AZ CLI INSTALLATION & UPDATE ==========
Write-Host " Checking for Azure CLI installation..."
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host " Installing Azure CLI..."
    $installer = "$env:TEMP\AzureCLI.msi"
    try {
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile $installer -UseBasicParsing
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$installer`" /quiet"
        Remove-Item $installer -Force
        Write-Host "Azure CLI installed. You may need to restart PowerShell."
    } catch {
        Write-Warning ("Failed to install Azure CLI: {0}" -f $_)
    }
} else {
    Write-Host "Ensuring Azure CLI is up-to-date..."
    try {
        & az upgrade --yes --only-show-errors
        Write-Host "Azure CLI is up-to-date."
    } catch {
        Write-Warning ("Failed to update Azure CLI: {0}" -f $_)
    }
}

# ========== m365 CLI (Microsoft 365 CLI) ==========
Write-Host " Checking for Microsoft 365 CLI (m365)..."
if (-not (Get-Command m365 -ErrorAction SilentlyContinue)) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host " Installing Microsoft 365 CLI globally (requires Node.js/npm)..."
        try {
            npm install -g @pnp/cli-microsoft365
            Write-Host "Microsoft 365 CLI installed."
        } catch {
            Write-Warning ("Failed to install Microsoft 365 CLI: {0}" -f $_)
        }
    } else {
        Write-Host "Node.js/npm not found. Microsoft 365 CLI was skipped."
    }
} else {
    Write-Host "Microsoft 365 CLI already installed."
}

# ========== PowerShell Help Update ==========
Update-Help -Force -ErrorAction Continue

Write-Host "All dependencies and tools installed and/or updated successfully."
