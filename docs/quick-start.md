# 1-Minute Quick Start Guide

This guide is designed for non-technical users who want to safely remove Microsoft Edge from Windows 10 or Windows 11 with minimal effort.

---

## Step 1: Open the Scripts Folder
1. Open Windows File Explorer.
2. Locate the folder where you downloaded or cloned `edge-removal-skill`.
3. Double-click to open the `scripts` folder.

You will see six files:
- `check-edge-status.bat`
- `check-edge-status.ps1`
- `remove-edge.bat`
- `remove-edge.ps1`
- `restore-edge.bat`
- `restore-edge.ps1`

---

## Step 2: Check Current Status (Recommended)
Before changing anything, check what is currently installed:
1. Double-click `check-edge-status.bat`.
2. A Windows User Account Control (UAC) prompt may appear asking for permission. Click **Yes**.
3. A command window will open displaying an audit of your system:
   - Green `[PASS]` marks indicate clean/blocked components.
   - Red `[FAIL]` marks indicate active Edge components or missing blocker policies.
4. Press any key to close the window.

---

## Step 3: Remove Microsoft Edge
1. Right-click on `remove-edge.bat`.
2. Click **Run as administrator**.
3. When the User Account Control (UAC) prompt appears, click **Yes**.
4. The script will show a warning summary. Type `y` and press **Enter** to confirm.
5. The script will automatically:
   - Close any running Edge or background WebView processes.
   - Bypass system uninstall locks.
   - Force-uninstall Edge.
   - Remove shortcuts from your desktop and Start menu.
   - Apply permanent Windows Update blocking policies.
6. Once complete, you will see a green success message:
   `MICROSOFT EDGE REMOVAL & PREVENTION WORKFLOW COMPLETED SUCCESSFULLY!`
7. Press any key to exit.

---

## Step 4: Verify Removal
1. Double-click `check-edge-status.bat`.
2. The report should now show:
   `OVERALL STATUS: [PASS] REMOVED AND BLOCKED (System is fully compliant)`
3. Microsoft Edge is now completely gone from your system and will not be reinstalled by Windows Update.

---

## Need to Restore Edge Later?
If you ever change your mind or need to reinstall Edge or WebView2:
1. Right-click `restore-edge.bat` and select **Run as administrator**.
2. Type `y` and press **Enter**.
3. All blocker policies are cleared and update services are restored.
4. You can now download Microsoft Edge from Microsoft's website or install via:
   `winget install Microsoft.Edge`
