---
name: edge-removal
description: Safely audit, force-uninstall, and permanently prevent automatic reinstallation of Microsoft Edge and WebView2 on Windows 10/11. Terminates locked processes, clears organizational uninstall registry locks (NoRemove/SystemComponent), purges AppX packages, shortcuts, and App Paths registrations, and enforces Chromium Blocker Toolkit keys, Enterprise Group Policies, and disabled EdgeUpdate services and tasks.
license: MIT
compatibility: Windows 10 / Windows 11, PowerShell 5.1+, Local Administrator privileges required
metadata:
  version: 1.0.0
  platform: windows
  category: system-administration
allowed-tools: run_command read_file
---

# Microsoft Edge & WebView2 Removal and Prevention Skill

A standardized skill and automation package designed for AI agents and Windows system administrators to safely audit, uninstall, and permanently prevent automatic reinstallation of Microsoft Edge and WebView2.

## Overview & Capabilities

Microsoft Edge is deeply integrated into Windows with organizational registry locks (`NoRemove=1`, `SystemComponent=1`), locked background processes (`SearchHost.exe`, `msedgewebview2.exe`), AppX packages, and background update daemons (`edgeupdate`, `edgeupdatem`, scheduled tasks) that automatically reinstall Edge during Windows Update cycles.

This skill equips agents and users to:
1. **Audit System State**: Non-destructively inspect all 5 system domains (binaries, registry flags, services, scheduled tasks, and blocker policies) with human-readable CLI or structured JSON output.
2. **Execute Full Removal**: Terminate file-locking processes, bypass organizational policy locks, invoke native Chromium uninstallation flags via `setup.exe`, purge AppX packages, remove desktop/start menu shortcuts, and erase `App Paths` registrations.
3. **Enforce Permanent Prevention**: Configure Chromium Blocker Toolkit (`DoNotUpdateToEdgeWithChromium=1`), Enterprise EdgeUpdate Group Policies (`InstallDefault=0`, `UpdateDefault=0`), and permanently disable update services and scheduled tasks.
4. **Safely Restore**: Revert policies and re-enable services when Edge or WebView2 restoration is requested.

## Prerequisites

- **Operating System**: Windows 10 (1809+) or Windows 11 (all versions), 32-bit or 64-bit.
- **Shell**: Windows PowerShell 5.1 or PowerShell Core (7.x+).
- **Privileges**: Local Administrator rights (elevated token) are mandatory for modifying `HKLM` policies, stopping services, and removing system-level packages.

## Safety & Confirmation Protocol

Before executing destructive removal actions:
1. **Always audit first**: Run `scripts/check-edge-status.ps1` to examine the current state.
2. **Warn about WebView2 dependencies**: Removing WebView2 runtime may affect third-party applications relying on embedded web views (e.g., Microsoft Teams, Outlook, or certain game launchers).
3. **Require explicit confirmation**: Do not execute `scripts/remove-edge.ps1` without user approval or an explicit `-Force` parameter.

---

## Agent Workflows

### Workflow 1: Non-Destructive State Audit

Inspect whether Microsoft Edge or WebView2 is installed, running, or protected by reinstallation prevention policies.

**Command (Human-Readable CLI Output):**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1
```

**Command (Structured JSON for AI Agents):**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1 -Json
```

**Output Interpretation:**
- `EdgeInstalled`: `false` indicates binaries and processes are absent.
- `ServicesDisabled`: `true` indicates `edgeupdate`, `edgeupdatem`, and `MicrosoftEdgeElevationService` are disabled.
- `TasksDisabled`: `true` indicates Edge scheduled tasks are disabled.
- `PoliciesConfigured`: `true` indicates Blocker Toolkit and Group Policies are active.
- `OverallCompliant`: `true` confirms system is fully debloated and protected against reinstallation.

---

### Workflow 2: Complete Removal and Policy Blocking

Executes the end-to-end uninstallation sequence and applies permanent blocker policies.

**Automated / Agent Invocation:**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\remove-edge.ps1 -Force
```

**Interactive Execution (Prompts for User Confirmation):**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\remove-edge.ps1
```

**Execution Steps Performed:**
1. Verifies elevated Administrator token (self-elevates if run interactively).
2. Prompts user confirmation `[y/N]` (bypassed with `-Force` or `-Silent`).
3. Kills file-locking processes (`msedge`, `msedgewebview2`, `SearchHost`).
4. Clears `NoRemove=0` and `SystemComponent=0` in 32-bit and 64-bit Uninstall registry hives.
5. Invokes native `setup.exe --uninstall --system-level --force-uninstall`.
6. Purges AppX packages (`Remove-AppxPackage -AllUsers`) and online provisioned packages.
7. Deletes residual program directories under `Program Files` and `Program Files (x86)`.
8. Cleans shortcuts from Desktop, Start Menu, Quick Launch, and deletes `App Paths\msedge.exe`.
9. Sets `DoNotUpdateToEdgeWithChromium=1` in `HKLM:\SOFTWARE\Microsoft\EdgeUpdate`.
10. Sets Enterprise Policies (`InstallDefault=0`, `UpdateDefault=0`, per-app GUID blocks).
11. Disables `edgeupdate`, `edgeupdatem`, `MicrosoftEdgeElevationService`, and scheduled tasks.

---

### Workflow 3: System Restoration and Policy Unblocking

Reverts all blocker policies and restores update services so Microsoft Edge or WebView2 can be installed normally.

**Automated Invocation:**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\restore-edge.ps1 -Force
```

**Interactive Execution:**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\restore-edge.ps1
```

**Post-Restoration Installation Commands:**
```powershell
# Install Microsoft Edge
winget install Microsoft.Edge

# Install Microsoft Edge WebView2 Runtime
winget install Microsoft.EdgeWebView2Runtime
```

---

## Standalone Batch Launchers for Non-Technical Users

For users who prefer not to use PowerShell directly, double-clickable `.bat` wrappers with automatic User Account Control (UAC) elevation prompts are provided:
- `scripts\remove-edge.bat`: Single-click automated removal and prevention.
- `scripts\check-edge-status.bat`: Single-click system audit.
- `scripts\restore-edge.bat`: Single-click policy and service restoration.

## Error Handling & Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| `Access is denied` or exit code 1 | Process not elevated | Right-click the `.bat` file and select "Run as administrator" or open an elevated PowerShell window. |
| `EmbeddedBrowserWebView.dll locked` | `SearchHost.exe` holds DLL handle | Run `scripts\remove-edge.ps1` which includes a multi-cycle process termination loop. |
| Edge reappears after Windows Update | Major Windows feature upgrade recreated stubs | Re-run `scripts\check-edge-status.ps1` and reapply `scripts\remove-edge.ps1 -Force`. |
| Third-party app fails to render UI | App depends on WebView2 runtime | Run `scripts\restore-edge.ps1 -Force` and install WebView2 via `winget install Microsoft.EdgeWebView2Runtime`. |
