# Win-Cloud-Admin-Setup

A PowerShell script to install all common modules, CLI tools, and RSAT features for Azure, Microsoft 365, and Windows Server administration.

## Features

- Installs RSAT tools (GPO, Active Directory)
- Installs PowerShell modules for:
  - Microsoft Graph
  - Exchange Online
  - AzureAD (classic)
  - MSOnline
  - Az (ARM)
  - Microsoft Teams
  - SharePoint PnP
  - Defender
  - SharePoint Online Management
- Installs Azure CLI and Microsoft 365 CLI (if Node.js present)
- Handles both Server and Client OS

## Usage

1. Download `install-cloud-admin-tools.ps1`
2. Run PowerShell as Administrator
3. Execute:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope Process -Force
   .\install-cloud-admin-tools.ps1

