# OpenAI ChatGPT Integration Guide

This guide describes how to configure OpenAI ChatGPT (via Custom GPTs or ChatGPT Projects) to guide non-technical users through Microsoft Edge removal and prevention.

---

## 1. Overview of ChatGPT Artifacts

The repository provides ready-to-use artifacts in the `chatgpt/` directory:

| File | Purpose | Target Location in ChatGPT |
|---|---|---|
| `chatgpt/custom-instructions.md` | Persona, behavioral constraints, step-by-step guidance rules. | GPT Builder -> **Instructions** |
| `chatgpt/conversation-starters.json` | 4 clickable prompt chips on the chat landing page. | GPT Builder -> **Conversation Starters** |
| `chatgpt/gpt-setup-guide.md` | Non-technical setup manual. | Human reference / README |
| `chatgpt/openapi.yaml` | OpenAPI 3.1.0 schema for local REST API integration. | GPT Builder -> **Actions** (Optional) |

---

## 2. Setting Up in ChatGPT Plus / Team / Enterprise

### Quick Setup Steps
1. Log into [chatgpt.com](https://chatgpt.com) and navigate to **Explore GPTs** -> **Create**.
2. Click the **Configure** tab.
3. Set **Name**: `Edge & WebView2 Removal Assistant`.
4. Set **Description**: `Safely audit, uninstall, and permanently prevent automatic reinstallation of Microsoft Edge and WebView2 on Windows 10/11.`
5. Paste the contents of `chatgpt/custom-instructions.md` into **Instructions**.
6. Add the conversation starters from `chatgpt/conversation-starters.json`.
7. Upload the knowledge files: `README.md`, `docs/quick-start.md`, `docs/technical-reference.md`, `docs/troubleshooting.md`.
8. Click **Save** / **Update**.

---

## 3. Using ChatGPT Projects (For Team / Enterprise Users)

If you use ChatGPT Team or Enterprise Workspaces with Projects:
1. Create a new Project named `Edge Removal Toolkit`.
2. In Project Settings, paste `chatgpt/custom-instructions.md` into **Custom Instructions for this Project**.
3. In Project Files, upload all `.md` files from the `docs/` folder and `README.md`.
4. All team members working inside this Project will automatically inherit the skill instructions.

---

## 4. How the Assistant Interacts with Users

Because ChatGPT runs inside the user's web browser, it cannot execute PowerShell commands directly on local Windows PCs. The assistant is structured to:
1. Explain technical concepts in plain, reassuring language.
2. Direct non-technical users to single-click `.bat` files (`remove-edge.bat`, `check-edge-status.bat`).
3. Provide power users with copy-pasteable PowerShell one-liners.
4. Help troubleshoot errors (such as UAC elevation errors or file locks) by analyzing user log outputs.
