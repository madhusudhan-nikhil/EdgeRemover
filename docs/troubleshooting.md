# Troubleshooting Guide

This guide provides troubleshooting solutions for common issues encountered when removing Microsoft Edge or preventing its reinstallation.

---

## 1. "Access Denied" or Exit Code 1 Errors

### Cause
Modifying `HKLM` registry hives, disabling Windows services, or uninstalling system-level software requires elevated Administrator privileges. If a script is launched in a standard user token, Windows denies access.

### Solution
- **Using Batch Launchers**:
  Right-click `scripts\remove-edge.bat` and select **Run as administrator**. When prompted by Windows User Account Control (UAC), click **Yes**.
- **Using PowerShell**:
  1. Press `Windows Key + X` and select **Terminal (Admin)** or **Windows PowerShell (Admin)**.
  2. Navigate to the repository:
     ```powershell
     cd c:\_Projects\TVHack\edge-removal-skill
     ```
  3. Execute with bypass policy:
     ```powershell
     powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\remove-edge.ps1 -Force
     ```

---

## 2. File Lock on `EmbeddedBrowserWebView.dll` or Directories

### Cause
Windows background processes like `SearchHost.exe` (Windows Search indexing) or running instances of `msedgewebview2.exe` hold active file handles on `EmbeddedBrowserWebView.dll` inside `C:\Program Files (x86)\Microsoft\EdgeWebView`.

### Solution
The `scripts\remove-edge.ps1` script includes an automated 5-cycle termination loop. If you are performing manual cleanup:
1. Open Task Manager (`Ctrl + Shift + Esc`).
2. End the task `SearchHost.exe` and any running `msedge.exe` or `msedgewebview2.exe` processes.
3. Re-run `scripts\remove-edge.ps1 -Force`.
4. If a stubborn directory remains, the script automatically uses an empty directory mirror technique (`robocopy /MIR`) to purge locked folders upon reboot.

---

## 3. Microsoft Edge Reappears After Windows Cumulative Update

### Cause
Major Windows Feature Updates (such as upgrading between Windows 11 23H2 and 24H2) or certain cumulative rollup packages may refresh provisioned AppX manifests.

### Solution
1. Verify whether Edge binaries were actually re-downloaded:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1
   ```
2. If update services or AppX stubs were restored, re-run:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\remove-edge.ps1 -Force
   ```
   Because the blocker policies (`DoNotUpdateToEdgeWithChromium = 1`) and Group Policies remain in the registry, Edge cannot execute or update.

---

## 4. Third-Party App Fails to Open or Displays a Blank Window

### Cause
Certain modern Windows desktop apps (e.g., Microsoft Teams New, Outlook New, or some game launchers) rely on the **WebView2 Runtime** to render embedded web views.

### Solution
You can keep Edge removed while re-enabling WebView2 runtime:
1. Run the restore script to unblock update policies:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\restore-edge.ps1 -Force
   ```
2. Reinstall only the WebView2 Runtime via Windows Package Manager:
   ```powershell
   winget install Microsoft.EdgeWebView2Runtime
   ```
3. Re-apply the Chromium Blocker Toolkit to ensure standalone Edge browser remains blocked:
   ```powershell
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\EdgeUpdate" -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Type DWord -Force
   ```

---

## 5. PowerShell Execution Policy Restriction

### Symptom
`File ... cannot be loaded because running scripts is disabled on this system.`

### Solution
Windows defaults to `Restricted` script execution. You do not need to change machine-wide policies; simply launch the script with `-ExecutionPolicy Bypass`:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\remove-edge.ps1 -Force
```
Or double-click the corresponding `.bat` launcher, which automatically includes the `-ExecutionPolicy Bypass` flag.
