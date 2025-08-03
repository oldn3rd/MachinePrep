# PreMachinePrep.ps1
# Bootstraps a workstation: installs Git/Chocolatey, pulls MachinePrep repo, runs MachinePrep.ps1

$RepoUrl     = 'https://github.com/oldn3rd/MachinePrep.git'
$OneDrive    = [Environment]::GetEnvironmentVariable("OneDrive", "Machine")
$LocalPath   = Join-Path $OneDrive "GITHUB Repo\MachinePrep"
$ScriptToRun = 'MachinePrep.ps1'

function Ensure-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Chocolatey is already installed."
        return
    }

    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        throw "Chocolatey installation failed."
    }
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "Git is already installed."
        return
    }

    Write-Host "Installing Git via Chocolatey..."
    choco install git -y --no-progress

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git installation failed."
    }
}

function Clone-Or-Pull-Repo {
    if (Test-Path $LocalPath) {
        Write-Host "Repo already exists. Pulling latest..."
        Set-Location $LocalPath
        git pull
    } else {
        Write-Host "Cloning repo to $LocalPath..."
        git clone $RepoUrl $LocalPath
        Set-Location $LocalPath
    }
}

function Run-PrepScript {
    $ScriptFullPath = Join-Path $LocalPath $ScriptToRun
    if (-not (Test-Path $ScriptFullPath)) {
        throw "Script not found: $ScriptFullPath"
    }

    Write-Host "Unblocking and executing: $ScriptToRun"
    Unblock-File -Path $ScriptFullPath

    try {
        & $ScriptFullPath
    } catch {
        Write-Error "Script execution failed: $_"
    }
}

# Main logic
try {
    Ensure-Chocolatey
    Ensure-Git
    Clone-Or-Pull-Repo
    Run-PrepScript
} catch {
    Write-Error "Setup failed: $_"
}
