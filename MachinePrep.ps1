$ScriptVersion = '1.5.1'
$LogFile = Join-Path $PSScriptRoot "bootstrap.log"

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

    $color = switch ($Level) {
        "Error"   { "Red" }
        "Warning" { "Yellow" }
        "Debug"   { "Cyan" }
        default   { "Gray" }
    }
    Write-Host $line -ForegroundColor $color
}

Write-Log "==== MachinePrep.ps1 Started (v$ScriptVersion) ===="

# ========== Node.js for m365 CLI ==========
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Log "Node.js/npm not found. Installing via Chocolatey..."
    try {
        choco install nodejs -y --no-progress
        Write-Log "Node.js installed successfully."
    } catch {
        Write-Log "Node.js install failed: $_" "Error"
    }
} else {
    Write-Log "Node.js/npm already present."
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
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
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

# ========== Microsoft 365 CLI ==========
Write-Log "Checking for Microsoft 365 CLI (m365)..."
if (-not (Get-Command m365 -ErrorAction SilentlyContinue)) {
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

# ========== PowerShell Help ==========
Write-Log "Updating PowerShell Help..."
try {
    Update-Help -Force -ErrorAction Continue
    Write-Log "Help updated successfully."
} catch {
    Write-Log "Help update failed: $_" "Warning"
}

Write-Log "==== MachinePrep.ps1 Completed ===="
Exit 0
