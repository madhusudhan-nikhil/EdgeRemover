# Claude Code Project Instructions: Microsoft Edge Removal & Prevention Skill

This project provides a standardized skill and automation toolkit to audit, uninstall, and prevent the reinstallation of Microsoft Edge and WebView2 on Windows 10 and 11.

## Quick Commands

### State Audit (Read-Only / Non-Destructive)
Run this command first to verify the current installation and policy compliance:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1
```
For machine-readable JSON:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1 -Json
```

### Full Removal & Prevention (Destructive / Elevated)
Execute elevated uninstallation, AppX purging, shortcut cleanup, and policy enforcement:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\remove-edge.ps1 -Force
```

### System Restoration (Policy Unblock)
Revert blocker policies and restore update services to enable Edge or WebView2 installation:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\restore-edge.ps1 -Force
```

---

## Available Skills

- `/edge-removal`: Modular project skill configured in `.claude/skills/edge-removal/SKILL.md`. When the user asks about removing Edge, checking status, or unblocking updates, load and follow this skill.

---

## Repository Layout

```
edge-removal-skill/
├── SKILL.md                          # Antigravity & AgentSkills specification
├── CLAUDE.md                         # This file (session startup instructions)
├── .claude/
│   ├── settings.json                 # Tool execution permissions
│   └── skills/
│       └── edge-removal/
│           └── SKILL.md              # Claude Code project skill (/edge-removal)
├── chatgpt/                          # Custom GPT bundle (instructions, starters, OpenAPI)
├── scripts/
│   ├── remove-edge.ps1               # PowerShell removal & blocker engine
│   ├── remove-edge.bat               # Elevated batch launcher for non-technical users
│   ├── check-edge-status.ps1         # Status verification engine
│   ├── check-edge-status.bat         # Elevated batch status launcher
│   ├── restore-edge.ps1              # Policy reversal & service restoration engine
│   └── restore-edge.bat              # Elevated batch restore launcher
└── docs/                             # Guides, technical reference, troubleshooting
```

---

## Agent Safety & Execution Rules

1. **Elevation Check**: All modifying scripts require Windows Administrator privileges. Check status first; if not elevated, instruct the user to run an elevated terminal or double-click the corresponding `.bat` launcher.
2. **Never Suppress WebView2 Warning**: Inform users that removing WebView2 may break apps that rely on embedded browser controls (e.g., Microsoft Teams, Outlook, or gaming stores).
3. **Always Check Status**: Run `scripts\check-edge-status.ps1` before and after executing removal or restoration actions to report empirical evidence.
4. **Minimal Changes**: Do not modify system files outside the documented Edge registry keys and application directories.
