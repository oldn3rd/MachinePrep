# MachinePrep.ps1

A single PowerShell script to fully prepare a Windows admin workstation for managing Microsoft 365, Intune, Azure, and Windows environments.

- Installs required PowerShell modules, CLIs, and supporting tools
- Logs all output to `bootstrap.log` in the current directory
- Safe to re-run — handles idempotent installs and updates
- No cloning or setup needed — just run it via a one-liner

---

## 🚀 Quick Start

> Open **PowerShell as Administrator**, then run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; `
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/oldn3rd/MachinePrep/main/MachinePrep.ps1'))
```

---

## 🛠️ What It Installs

- Chocolatey (if missing)
- Git (if missing)
- Node.js (for Microsoft 365 CLI)
- Azure CLI
- Microsoft 365 CLI (`m365`)
- PowerShell modules:
  - Microsoft.Graph
  - MicrosoftTeams
  - ExchangeOnlineManagement
  - Az
  - SharePointPnPPowerShellOnline
  - Defender
  - Microsoft.Online.SharePoint.PowerShell

---

## ⚙️ Script Parameters

You can run the script with the following options (when downloaded locally):

| Parameter         | Description                                      |
|------------------|--------------------------------------------------|
| `-ForceReinstall` | Forces reinstall of all tools and modules       |
| `-Silent`         | Suppresses most console output (logs remain)    |
| `-NoBanner`       | Skips the header/banner output                  |
| `-DebugOutput`    | Enables verbose debug messages                  |

**Example:**
```powershell
.\MachinePrep.ps1 -ForceReinstall -DebugOutput
```

---

## 📄 Logging

All actions and errors are logged to `bootstrap.log` in the directory where the script is executed.

---

## ❗ Note

`PreMachinePrep.ps1` has been retired.  
Use only `MachinePrep.ps1` moving forward.

---

## 🙋‍♂️ Support

Questions, issues, or suggestions?  
Open a GitHub issue or contact [oldn3rd](https://github.com/oldn3rd).

---

## 📄 License

MIT License © 2025 oldn3rd
