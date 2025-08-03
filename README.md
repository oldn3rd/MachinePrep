# MachinePrep

MachinePrep is a PowerShell-based provisioning toolkit that bootstraps a Windows admin workstation with essential tools, PowerShell modules, CLIs, and optional admin utilities for Microsoft 365, Azure, and on-prem AD environments.

## Features

- Checks for internet and admin access
- Installs Chocolatey and Git if missing
- Installs common admin tools and utilities
- Adds RSAT tools based on OS (Server or Client)
- Installs/updates PowerShell modules:
  - Microsoft.Graph
  - ExchangeOnlineManagement
  - AzureAD / MSOnline
  - Az
  - MicrosoftTeams
  - SharePointPnPPowerShellOnline
  - Defender
  - Microsoft.Online.SharePoint.PowerShell
  - SharePointOnline
  - Teams
- Installs or updates:
  - Azure CLI
  - Microsoft 365 CLI (via npm if available)
- Updates PowerShell Help

## Structure

- `MachinePrep.ps1`  
  Installs core toolset and modules. Run as Administrator.

- `Run-MachinePrep.ps1`  
  Bootstraps Git + Chocolatey, clones the repo, and runs `MachinePrep.ps1`.

## How to Use

### 1. First-time setup

Open PowerShell as Administrator and run this one-liner:

```powershell
iwr -useb https://raw.githubusercontent.com/oldn3rd/MachinePrep/main/Run-MachinePrep.ps1 | iex
