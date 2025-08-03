MachinePrep
A PowerShell-based automation script for bootstrapping a Windows admin workstation with essential tools, modules, and configuration for Microsoft 365, Azure, PowerShell scripting, and general IT administration.

📦 What It Does
Installs Chocolatey and Git (if missing)

Clones the MachinePrep GitHub repository to a standard path:
C:\Users\andy\OneDrive - The Office365 Dev Environment\GITHUB Repo\MachinePrep

Executes the MachinePrep.ps1 setup script from the cloned repo

🧰 Tools Installed via Chocolatey
Git

Azure CLI

Node.js (for Microsoft 365 CLI)

LogExpert

VS Code

Sysinternals

Windows Terminal

📚 PowerShell Modules Installed
Microsoft.Graph

ExchangeOnlineManagement

AzureAD

MSOnline

MicrosoftTeams

SharePointPnPPowerShellOnline

Microsoft.Online.SharePoint.PowerShell

Az

Microsoft.Graph.Intune

Microsoft.Graph.DeviceManagement

ImportExcel

PSWriteHTML

CredentialManager

PSWindowsUpdate

🚀 Usage
Open PowerShell as Administrator and run:

arduino
Copy
Edit
& "C:\Users\andy\OneDrive - The Office365 Dev Environment\GITHUB Repo\Run-MachinePrep.ps1"
This will:

Install prerequisites (Chocolatey, Git)

Clone the GitHub repo to your default path

Run the setup script: MachinePrep.ps1

✅ Prerequisites
Windows 10/11

PowerShell 5.1 or higher

Administrator privileges

Internet access

📂 File Structure
mathematica
Copy
Edit
GITHUB Repo
├── MachinePrep
│   └── MachinePrep.ps1
└── Run-MachinePrep.ps1
🛠 Roadmap
Add logging and WhatIf/TestMode

Build .intunewin package for Intune deployments

Add optional ScriptRunner with interactive menu

Git-aware local update sync

🔒 Notes
This setup assumes your GitHub scripts are stored consistently under OneDrive. To avoid sync conflicts, mark Git repos as “Always keep on this device.”

👤 Author
Andy
Senior Engineer, New Zealand 🇳🇿
GitHub: @oldn3rd

