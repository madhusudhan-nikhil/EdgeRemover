# Google Antigravity Integration Guide

This guide details how to import and utilize the `edge-removal` skill within Google Antigravity (AGY) SDK agents and multi-agent workflows.

---

## 1. Skill Standard Compliance

The `edge-removal` skill strictly adheres to the open [Agent Skills specification](https://agentskills.io), featuring:
- Standard YAML frontmatter with `name: edge-removal` and a descriptive capability string (<= 1024 characters).
- Progressive disclosure architecture:
  1. **Phase 1 (Discovery)**: The agent discovers the skill name and description from the frontmatter index.
  2. **Phase 2 (Activation)**: When a relevant query is received, the agent loads `SKILL.md` body.
  3. **Phase 3 (Execution)**: The agent executes target scripts in `scripts/` using authorized tools (`run_command`).

---

## 2. Configuring Antigravity Agent with the Skill

To load this skill in a Python script using the Google Antigravity SDK:

```python
from antigravity import Agent, LocalAgentConfig

# Configure agent with path to the edge-removal-skill directory
config = LocalAgentConfig(
    skills_paths=[
        r"c:\_Projects\TVHack\edge-removal-skill"
    ],
    tools=[
        "run_command",
        "read_file"
    ]
)

agent = Agent(config=config)
```

---

## 3. Supported Natural Language Prompts

Once imported, the Antigravity agent will automatically recognize user requests matching any of the following intents:

### Audit & State Checking
- *"Check if Microsoft Edge is installed or running on this PC."*
- *"Audit the EdgeUpdate services and Group Policy status."*
- *"Is Microsoft Edge blocked from updating?"*

**Agent Action**: Executes `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1 -Json` and analyzes the JSON response.

### Removal & Prevention
- *"Uninstall Microsoft Edge and prevent it from reinstalling."*
- *"Remove Edge and WebView2 from this Windows 11 machine."*
- *"Debloat Edge and block EdgeUpdate services."*

**Agent Action**: 
1. Queries current status via `check-edge-status.ps1 -Json`.
2. Confirms intent with user (highlighting any WebView2 implications).
3. Executes `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\remove-edge.ps1 -Force`.
4. Runs verification check to confirm compliance.

### Reversibility & Restoration
- *"Unblock EdgeUpdate so I can reinstall Microsoft Edge."*
- *"Restore Edge policies and re-enable the update services."*

**Agent Action**: Executes `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\restore-edge.ps1 -Force`.

---

## 4. Required Agent Tools & Permissions

To allow an Antigravity agent to run the scripts autonomously:
- `run_command`: Required to execute PowerShell command lines.
- `read_file`: Required to inspect script sources or log files.
- Elevated Token: The host process hosting the agent must run with Administrator permissions if executing `remove-edge.ps1` or `restore-edge.ps1`.
