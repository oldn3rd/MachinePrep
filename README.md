# MachinePrep

**Version:** 1.0.0  
**Author:** [oldn3rd](https://github.com/oldn3rd)  
**Purpose:** Prepare a fresh Windows workstation or admin VM with essential tools, PowerShell modules, and CLI utilities for IT administrators.

---

## 📦 Features

- Checks for admin rights and internet connectivity
- Installs:
  - Chocolatey (if missing)
  - Azure CLI
  - Microsoft 365 CLI (if Node.js is present)
- Adds RSAT features (Active Directory & Group Policy) based on OS type
- Installs and updates essential PowerShell modules:
  - Microsoft.Graph
  - ExchangeOnlineManagement
  - AzureAD & MSOnline
  - Az
  - MicrosoftTeams
  - SharePointPnPPowerShellOnline
  - Microsoft.Online.SharePoint.PowerShell
  - Defender
  - SharePointOnline
  - Teams
- Fully scriptable, modular, and rerunnable (safe to re-execute)

---

## 📁 Repo Structure

```
MachinePrep/
├── LICENSE
├── README.md
├── MachinePrep.ps1           # The main prep script
└── PreMachinePrep.ps1        # Bootstraps Git + Choco + pulls repo and runs MachinePrep
```

---

## 🚀 Quick Start (One-Liner)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; `
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/oldn3rd/MachinePrep/main/PreMachinePrep.ps1'))
```

---

## 🛠 Requirements

- Windows 10/11 or Windows Server 2016+
- Admin privileges
- Internet access
- Optional: Node.js + npm (to install Microsoft 365 CLI)

---

## 💡 Notes

- Safe to run multiple times; tools/modules will be checked and updated as needed.
- Logs and errors are printed inline for debugging.
- Can be used in automated setup pipelines or manually on-demand.

---

## 📃 License

MIT License — see [LICENSE](LICENSE)
