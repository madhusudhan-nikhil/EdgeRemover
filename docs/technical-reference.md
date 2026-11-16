# Technical Reference: Edge Removal & Policy Prevention

This document provides a comprehensive technical reference of all Windows registry keys, GUIDs, service names, scheduled tasks, and command-line switches utilized by the `edge-removal-skill` package.

---

## 1. Registry Specifications

### 1.1 Organizational Uninstall Locks (Bypass)
Windows prevents GUI uninstallation of Microsoft Edge and WebView2 by marking their entries with `NoRemove` and `SystemComponent` DWORD values in the 32-bit (WOW6432Node) and 64-bit Uninstall registry hives.

| Hive / Path | Value Name | Type | Target Value | Purpose |
|---|---|---|---|---|
| `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge` | `NoRemove` | `REG_DWORD` | `0` | Unlocks uninstall capability in Windows installer databases. |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge` | `NoRemove` | `REG_DWORD` | `0` | 64-bit hive unlock. |
| `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView` | `NoRemove` | `REG_DWORD` | `0` | Unlocks WebView2 uninstallation. |
| `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView` | `SystemComponent` | `REG_DWORD` | `0` | Unmarks WebView2 as a protected system component. |

---

### 1.2 Chromium Blocker Toolkit Registry Keys
Microsoft provides an official Blocker Toolkit mechanism that instructs Windows Update not to deliver the Chromium-based Microsoft Edge automatically.

| Hive / Path | Value Name | Type | Value | Effect |
|---|---|---|---|---|
| `HKLM:\SOFTWARE\Microsoft\EdgeUpdate` | `DoNotUpdateToEdgeWithChromium` | `REG_DWORD` | `1` | Prohibits Windows Update from delivering Edge on 64-bit systems. |
| `HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate` | `DoNotUpdateToEdgeWithChromium` | `REG_DWORD` | `1` | Prohibits Windows Update from delivering Edge on 32-bit subsystem. |

---

### 1.3 Enterprise EdgeUpdate Group Policies
Enterprise Administrative Templates (`msedgeupdate.admx`) control EdgeUpdate behavior. Configuring these values ensures EdgeUpdate daemons cannot download or install binaries.

| Registry Path | Value Name | Type | Value | Effect |
|---|---|---|---|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate` | `InstallDefault` | `REG_DWORD` | `0` | Prohibits installation of all Microsoft Edge applications by default. |
| `HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate` | `UpdateDefault` | `REG_DWORD` | `0` | Prohibits automatic background updates for all Edge applications. |
| `HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate` | `Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}` | `REG_DWORD` | `0` | Prohibits installation of Microsoft Edge Stable. |
| `HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate` | `Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}` | `REG_DWORD` | `0` | Prohibits updates for Microsoft Edge Stable. |
| `HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate` | `Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}` | `REG_DWORD` | `0` | Prohibits installation of Microsoft Edge WebView2. |
| `HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate` | `Update{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}` | `REG_DWORD` | `0` | Prohibits updates for Microsoft Edge WebView2. |
| `HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate` | `DoNotUpdateToEdgeWithChromium` | `REG_DWORD` | `1` | Enforces blocker toolkit via Group Policy. |

---

### 1.4 Known Application GUIDs

| Application | GUID | Description |
|---|---|---|
| **Microsoft Edge Stable** | `{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}` | Primary Microsoft Edge browser client identifier. |
| **Microsoft Edge WebView2** | `{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}` | Embedded WebView2 Runtime client identifier. |
| **Copilot Under Edge** | `{C50565E9-CCCF-44B4-BA15-5AC5C6569197}` | Edge-integrated AI sidebar service. |
| **EdgeUpdate Daemon** | `{F3C4FE00-EFD5-403B-9569-398A20F1BA4A}` | Edge background updater binary identifier. |

---

### 1.5 CLI Registrations (`App Paths`)
Windows Explorer and CLI terminals resolve `msedge` via `App Paths`. These entries must be purged to prevent dead command invocations:
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe`
- `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe`
- `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe`

---

## 2. Windows Services

The following background Windows services handle update checking, telemetry, and privilege elevation for Microsoft Edge:

| Service Name | Display Name | Normal Start Type | Blocked State |
|---|---|---|---|
| `edgeupdate` | Microsoft Edge Update Service | Automatic / Manual | **Disabled** (Stopped) |
| `edgeupdatem` | Microsoft Edge Update Service (edgeupdatem) | Manual | **Disabled** (Stopped) |
| `MicrosoftEdgeElevationService` | Microsoft Edge Elevation Service | Manual | **Disabled** (Stopped) |

### Disabling Commands:
```powershell
Stop-Service -Name edgeupdate, edgeupdatem, MicrosoftEdgeElevationService -Force -ErrorAction SilentlyContinue
Set-Service -Name edgeupdate, edgeupdatem, MicrosoftEdgeElevationService -StartupType Disabled
& sc.exe config edgeupdate start= disabled
& sc.exe config edgeupdatem start= disabled
& sc.exe config MicrosoftEdgeElevationService start= disabled
```

---

## 3. Scheduled Tasks

EdgeUpdate registers scheduled tasks to trigger background scans regardless of service status. These tasks are disabled by the script:

1. **System Tasks**:
   - `MicrosoftEdgeUpdateTaskMachineCore` (or tasks matching `MicrosoftEdgeUpdateTaskMachineCore*`)
   - `MicrosoftEdgeUpdateTaskMachineUA` (or tasks matching `MicrosoftEdgeUpdateTaskMachineUA*`)
2. **User-Scoped Tasks**:
   - `MicrosoftEdgeUpdateTaskUserS-1-5-...Core{...}`
   - `MicrosoftEdgeUpdateTaskUserS-1-5-...UA{...}`

### Disabling Commands:
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like "*Edge*" } | ForEach-Object {
    Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue
    & schtasks.exe /change /tn "$($_.TaskPath)$($_.TaskName)" /disable 2>$null
}
```

---

## 4. Native `setup.exe` Uninstallation Switches

When Microsoft Edge or WebView2 is installed, the Chromium installer resides in:
- `C:\Program Files (x86)\Microsoft\Edge\Application\<Version>\Installer\setup.exe`
- `C:\Program Files (x86)\Microsoft\EdgeWebView\Application\<Version>\Installer\setup.exe`

### Switch Breakdown:
| Switch | Purpose |
|---|---|
| `--uninstall` | Directs `setup.exe` to initiate the uninstallation routine. |
| `--msedge` | Targets Microsoft Edge browser binaries and COM handlers. |
| `--msedgewebview` | Targets Microsoft Edge WebView2 runtime. |
| `--channel=beta` (or stable) | Uninstalls within the specified update channel. |
| `--system-level` | Directs uninstallation of machine-wide components. |
| `--verbose-logging` | Produces diagnostic log entries in `%TEMP%`. |
| `--force-uninstall` | Bypasses UI dialogs and forces de-registration without user prompt. |

---

## 5. AppX Package Purging

Windows maintains provisioned AppX package stubs for newly created user profiles. Both active and provisioned packages must be removed:

```powershell
# Remove active user packages
Get-AppxPackage -AllUsers -Name "*MicrosoftEdge*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

# Remove provisioned online packages (prevents reappearing in new profiles)
Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*MicrosoftEdge*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
```
