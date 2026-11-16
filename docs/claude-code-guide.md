# Claude Code Integration Guide

This guide explains how to use the `edge-removal` skill within Anthropic's **Claude Code** CLI terminal.

---

## 1. Overview & Setup

Claude Code natively reads project-level configuration files upon startup:
1. `CLAUDE.md` (root): Loaded into Claude's system prompt on every session. Defines quick commands, style rules, and safety protocols.
2. `.claude/settings.json`: Configures auto-allow permissions for non-destructive status checks while prompting for user approval before executing destructive actions.
3. `.claude/skills/edge-removal/SKILL.md`: Registers the `/edge-removal` slash-command.

---

## 2. Using the Skill in Claude Code

Launch Claude Code in the repository directory:
```bash
cd c:\_Projects\TVHack\edge-removal-skill
claude
```

### Method A: Slash-Command (`/edge-removal`)
Type `/edge-removal` in the Claude prompt:
```
> /edge-removal
```
Claude Code will:
1. Execute `scripts/check-edge-status.ps1 -Json` to audit the current state.
2. Display a summary of installed binaries, services, and policies.
3. Prompt you for confirmation before executing removal.
4. Execute `scripts/remove-edge.ps1 -Force` upon confirmation.
5. Re-run `check-edge-status.ps1` to verify clean removal.

### Method B: Natural Language
You can also ask Claude naturally:
- *"Check if Edge or WebView2 is installed."*
- *"Remove Edge and make sure Windows Update never brings it back."*
- *"Re-enable Edge update services so I can install Edge again."*

---

## 3. Tool Permissions & Security

In `.claude/settings.json`, permissions are partitioned for security:

```json
{
  "permissions": {
    "allow": [
      "Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\\check-edge-status.ps1*)"
    ],
    "ask": [
      "Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\\remove-edge.ps1*)",
      "Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\\restore-edge.ps1*)"
    ]
  }
}
```

- **Auto-Allowed (`allow`)**: Claude Code runs `check-edge-status.ps1` without stopping to ask for permission.
- **Confirmation Required (`ask`)**: Claude Code will always display a prompt before running `remove-edge.ps1` or `restore-edge.ps1`, ensuring full control over destructive operations.
