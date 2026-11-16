---
name: edge-removal
description: Audit, uninstall, and permanently prevent automatic reinstallation of Microsoft Edge and WebView2 on Windows 10 and 11.
---

# Edge Removal Skill for Claude Code

When invoked via `/edge-removal` or when the user inquires about removing Microsoft Edge, checking Edge status, or unblocking updates:

## Workflow Execution Steps

1. **Audit Current State**:
   Execute the status check to see whether Edge is installed, if processes are running, and if blocker policies are active:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1 -Json
   ```

2. **Present Findings & Confirm Intent**:
   - Report the current status to the user (Installed, Removed, Policies Active).
   - If removal is requested, warn about WebView2 dependencies:
     > "Removing Microsoft Edge and WebView2 will permanently uninstall browser binaries, clear shortcuts, and disable update services. Applications requiring WebView2 (such as modern Microsoft Teams or desktop widgets) may be affected."
   - Confirm if the user wishes to proceed with full removal.

3. **Execute Removal**:
   Upon user confirmation:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\remove-edge.ps1 -Force
   ```

4. **Verify Post-Removal State**:
   Re-run the status check to confirm zero remaining binaries and active blocker policies:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1
   ```

5. **Restoration Guidance**:
   If the user ever needs to reinstall Edge or unblock updates:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\restore-edge.ps1 -Force
   ```
