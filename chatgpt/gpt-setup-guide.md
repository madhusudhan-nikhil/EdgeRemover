# Setting Up Your Custom GPT for Microsoft Edge Removal

This guide walks you through setting up a personalized AI Assistant inside OpenAI ChatGPT to guide you through auditing, removing, and preventing the reinstallation of Microsoft Edge on Windows.

---

## Prerequisites
- A ChatGPT Plus, Team, Enterprise, or Edu account with access to the **GPT Builder**.
- The `edge-removal-skill` repository files downloaded to your computer.

---

## Step 1: Open GPT Builder

1. Navigate to [chatgpt.com](https://chatgpt.com) in your web browser and sign in.
2. In the left-hand navigation sidebar, click on **Explore GPTs**.
3. Click the **+ Create** button in the top right corner.
4. Select the **Configure** tab to configure your GPT manually.

---

## Step 2: Fill In Basic Configuration

Copy and paste the following values into the corresponding fields:

- **Name**: `Edge & WebView2 Removal Assistant`
- **Description**: `Safely audit, uninstall, and permanently prevent automatic reinstallation of Microsoft Edge and WebView2 on Windows 10/11.`
- **Instructions**:
  Open the file `chatgpt/custom-instructions.md` in any text editor, copy the entire content, and paste it directly into the **Instructions** text box.

---

## Step 3: Add Conversation Starters

In the **Conversation Starters** section, add the following prompts (from `chatgpt/conversation-starters.json`):

1. `How do I check if Microsoft Edge is installed or blocked on my PC?`
2. `How can I safely remove Microsoft Edge without breaking Windows?`
3. `How do I stop Windows Update from automatically reinstalling Edge?`
4. `How do I restore Microsoft Edge and re-enable update services?`

---

## Step 4: Upload Knowledge Base Files

Under the **Knowledge** section, click **Upload files** and select the following documentation files from the repository:

1. `README.md`
2. `docs/quick-start.md`
3. `docs/technical-reference.md`
4. `docs/troubleshooting.md`

These files allow your Custom GPT to provide accurate registry keys, switch flags, and troubleshooting steps from the repository.

---

## Step 5: Configure Capabilities & Actions (Optional)

1. **Capabilities**:
   - Check **Code Interpreter & Data Analysis** (useful for pasting execution logs).
   - Check **Web Browsing** (allows GPT to look up latest Windows cumulative update notes).
2. **Actions (Optional)**:
   - If running a local management daemon or MCP server on your Windows PC, click **Create new action** and import `chatgpt/openapi.yaml`.

---

## Step 6: Save and Publish

1. Click the green **Save** or **Update** button in the top right corner.
2. Choose your preferred access level:
   - **Only me**: Private to your account.
   - **Anyone with a link**: Shareable with colleagues or family.
3. Click **Confirm**. Your Custom GPT is ready to use!
