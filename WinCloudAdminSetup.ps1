<#
.SYNOPSIS
    Installs common PowerShell modules, Azure CLI, Microsoft 365 CLI, and RSAT tools for administering Azure/Office 365/Windows environments.
.DESCRIPTION
    Detects OS type, installs RSAT features, Azure CLI, Microsoft 365 CLI, and all standard PowerShell modules for cloud and on-premises administration.
.NOTES
    Run as Administrator. Requires Internet access.
#>

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Warning "Please run this script as Administrator!"
    exit 1
}

Write-Host "🔍 Checking internet connectivity..."
try {
    Invoke-WebRequest -Uri "https://www.bing.com" -UseBasicParsing -TimeoutSec 10 | Out-Null
} catch {
    Write-Warning "No internet connectivity. Please connect and rerun."
    exit 1
}

Write-Host "🔍 Detecting operating system..."
$osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
$isServer = $osCaption -like '*Server*'

# NuGet provider check
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing NuGet provider..."
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers
}

# ========== RSAT INSTALL ==========
if ($isServer) {
    Write-Host "🖥 Detected Windows Server — using Add-WindowsFeature..."
    try {
        if (-not (Get-WindowsFeature GPMC).Installed) {
            Install-WindowsFeature GPMC -ErrorAction Stop
            Write-Host "✅ Installed GPMC"
        } else {
            Write-Host "✔️ GPMC already installed"
        }
        if (-not (Get-WindowsFeature RSAT-AD-PowerShell).Installed) {
            Install-WindowsFeature RSAT-AD-PowerShell -ErrorAction Stop
            Write-Host "✅ Installed RSAT AD Tools"
        } else {
            Write-Host "✔️ RSAT AD Tools already installed"
        }
    } catch {
        Write-Warning "❌ Failed to install server features: $_"
    }
} else {
    Write-Host "💻 Detected Windows Client — using Add-WindowsCapability..."
    $rsatFeatures = @(
        "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0",
        "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0"
    )
    foreach ($feature in $rsatFeatures) {
        try {
            $cap = Get-WindowsCapability -Online -Name $feature
            if ($cap.State -ne 'Installed') {
                Write-Host "📦 Installing RSAT Feature: $feature..."
                Add-WindowsCapability -Online -Name $feature -ErrorAction Stop
                Write-Host "✅ Installed $feature"
            } else {
                Write-Host "✔️ RSAT Feature already installed: $feature"
            }
        } catch {
            Write-Warning "❌ Failed to install RSAT Feature $feature: $_"
        }
    }
}

# ========== PowerShell Module List ==========
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
    # Optionally add "Microsoft.PowerApps.Administration.PowerShell", "Microsoft.PowerApps.PowerShell"
)

Write-Host "🔍 Checking and installing required PowerShell modules..."
foreach ($mod in $modules) {
    if (-not (Get-Module -ListAvailable -Name $mod.Name)) {
        Write-Host "📦 Installing module: $($mod.Name)..."
        try {
            Install-Module -Name $mod.Name -Force -AllowClobber -Scope AllUsers -ErrorAction Stop
            Write-Host "✅ Installed $($mod.Name)"
        } catch {
            Write-Warning "❌ Failed to install $($mod.Name): $_"
        }
    } else {
        Write-Host "✔️ Module already available: $($mod.Name)"
    }
}

# ========== AZ CLI ==========
Write-Host "🔍 Checking for Azure CLI installation..."
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing Azure CLI..."
    $installer = "$env:TEMP\AzureCLI.msi"
    try {
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile $installer -UseBasicParsing
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$installer`" /quiet"
        Remove-Item $installer -Force
        Write-Host "✅ Azure CLI installed. You may need to restart PowerShell."
    } catch {
        Write-Warning "❌ Failed to install Azure CLI: $_"
    }
} else {
    Write-Host "✔️ Azure CLI already installed."
}

# ========== Microsoft 365 CLI ==========
Write-Host "🔍 Checking for Microsoft 365 CLI..."
if (-not (Get-Command m365 -ErrorAction SilentlyContinue)) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "📦 Installing Microsoft 365 CLI globally (requires Node.js/npm)..."
        try {
            npm install -g @pnp/cli-microsoft365
            Write-Host "✅ Microsoft 365 CLI installed."
        } catch {
            Write-Warning "❌ Failed to install Microsoft 365 CLI: $_"
        }
    } else {
        Write-Warning "Node.js/npm not found. Install Node.js to use Microsoft 365 CLI (https://nodejs.org/)."
    }
} else {
    Write-Host "✔️ Microsoft 365 CLI already installed."
}

Write-Host "🎉 All dependencies installed successfully."
