# Browserbase Plugin Analysis

## How Browserbase Works

### Architecture Overview

**Browserbase does NOT show a local browser.** Everything runs in the cloud. Here's how:

1. **SessionStart Hook** → Starts a Node.js forwarding server
2. **Forwarding Server** → Intercepts MCP browser commands via Unix socket
3. **Commands Forwarded** → Sent to Browserbase cloud using Stagehand SDK
4. **Cloud Browser** → Runs remotely on Browserbase infrastructure
5. **Results Return** → Screenshots/data come back from cloud API

### Key Files

#### `.claude-plugin/plugin.json`
```json
{
  "name": "browserbase",
  "description": "Use Browserbase cloud browsers with Claude Code instead of local Chrome",
  "version": "1.0.0"
}
```

#### `hooks/hooks.json`
Registers 3 hooks:
- **SessionStart**: Starts forwarding server on session start
- **PreToolUse**: Logs browser tool usage
- **SessionEnd**: Stops forwarding server on session end

#### `scripts/session-start.sh`
- Auto-installs npm dependencies if missing
- Starts `node index.js` forwarding server in background
- Saves PID to `~/.browserbase/state/server.pid`
- Outputs system message with debug URL

#### `index.js` (Entry Point)
- Validates `BROWSERBASE_API_KEY` and `BROWSERBASE_PROJECT_ID` env vars
- Creates Unix socket at `/tmp/claude-mcp-browser-bridge-<user>`
- Starts ForwardingServer listening on socket

#### `forwarding-server.js` (Core Logic)
- **Socket Interception**: Listens on Unix socket, backs up original MCP socket
- **Command Processing**: Receives MCP browser commands (navigate, screenshot, click, etc.)
- **Forwarding**: Sends commands to Browserbase via `browserbase-client.js`
- **Response**: Returns results in MCP format

#### `browserbase-client.js` (Cloud API)
- Uses `@browserbasehq/stagehand` SDK to control cloud browsers
- Creates cloud sessions with `keepAlive: true`, `timeout: 21600` (6 hours)
- Gets debug URL: `stagehand.browserbaseDebugURL`
- Writes debug URL to `~/.browserbase/state/debug_url`
- Implements all browser actions (navigate, click, type, screenshot, etc.) via Stagehand

### Socket Takeover Mechanism

**Critical:** Browserbase intercepts Claude Code's MCP browser commands by:

1. **Backing up original socket**: `mv /tmp/claude-mcp-browser-bridge-user /tmp/claude-mcp-browser-bridge-user.backup`
2. **Creating new socket**: Creates own socket at same path
3. **Intercepting all commands**: Claude Code sends to Browserbase's socket instead
4. **Forwarding to cloud**: Commands go to Browserbase API, not local Chrome
5. **On shutdown**: Restores original socket from backup

### User Experience

**No local browser visible!** User only sees:

1. System message on session start:
   ```
   [Browserbase] Browserbase plugin active (server PID: 12345)
   ```

2. Debug URL provided:
   ```
   Live debug URL: https://browserbase.com/sessions/sess_xyz/debug
   ```

3. User can click debug URL to watch browser session in real-time via Browserbase's web interface (session recording)

### Installation Flow

```bash
# Add marketplace
/plugin marketplace add browserbase/claude-code-plugin

# Install plugin
/plugin install browserbase@claude-code-plugin

# Run setup (stores credentials)
~/.claude/plugins/browserbase/scripts/setup.sh
# Prompts for API key and Project ID
# Saves to ~/.browserbase/credentials

# Restart Claude Code
# SessionStart hook auto-runs, starts forwarding server
```

### Credentials Management

Stored in `~/.browserbase/credentials`:
```json
{
  "apiKey": "bb_api_key_xyz",
  "projectId": "proj_abc123"
}
```

Also persisted to `CLAUDE_ENV_FILE` so all bash commands can access them.

---

## ContextFort vs Browserbase Comparison

| Feature | ContextFort | Browserbase |
|---------|-------------|-------------|
| **Browser Location** | Local Chrome visible to user | Cloud browser (remote) |
| **Visual Feedback** | Chrome window opens locally | No local window, only debug URL |
| **Session Recording** | Local dashboard at localhost:8080 | Cloud dashboard via debug URL |
| **Binary Download** | Downloads Chrome for Testing (~170MB) | No download needed |
| **Hook Type** | PreToolUse only | SessionStart + PreToolUse + SessionEnd |
| **Interception Method** | Launches isolated Chrome before tool use | Takes over MCP socket |
| **Extension Loading** | Loads ContextFort extension in local Chrome | N/A (cloud browser) |
| **Data Storage** | Local (~/.contextfort/) | Cloud (Browserbase infrastructure) |
| **Cost** | Free (self-hosted) | Requires Browserbase subscription |
| **Network Requirement** | None (runs offline after install) | Always requires internet |
| **Latency** | Low (local) | Higher (network round-trip) |

---

## Key Architectural Differences

### ContextFort Approach
```
User requests browser tool
    ↓
PreToolUse hook checks if Chrome running
    ↓
If not running, launch isolated Chrome locally
    ↓
Tool executes in local Chrome (user sees it)
    ↓
Extension captures events → saves locally
    ↓
Dashboard shows session data from local files
```

### Browserbase Approach
```
User starts session
    ↓
SessionStart hook starts forwarding server
    ↓
Server takes over MCP socket
    ↓
User requests browser tool
    ↓
Command intercepted by forwarding server
    ↓
Server forwards to Browserbase cloud API
    ↓
Cloud browser executes (user doesn't see it)
    ↓
Results return from cloud
    ↓
User can watch via debug URL (session recording)
```

---

## Key Insights for ContextFort

### What We Can Learn

1. **SessionStart Hook**: Browserbase uses this to start their server BEFORE any browser tools are used. ContextFort could use this for:
   - Pre-launching Chrome on session start (avoid first-use delay)
   - Starting dashboard server automatically
   - Validating Chrome installation

2. **SessionEnd Hook**: Automatically cleanup on session end:
   - Kill Chrome process
   - Delete temp profiles
   - Stop dashboard server

3. **System Messages**: Browserbase outputs JSON with `systemMessage` field to show messages to user:
   ```json
   {
     "hookSpecificOutput": {
       "hookEventName": "SessionStart",
       "additionalContext": "..."
     },
     "systemMessage": "[Browserbase] Browserbase plugin active"
   }
   ```

4. **Debug URLs**: Providing clickable URLs for user to watch sessions is great UX

5. **Auto-dependency Installation**: Their SessionStart hook auto-runs `npm install` if dependencies missing

### What ContextFort Does Better

1. **Local Control**: User can see and interact with browser directly
2. **Privacy**: All data stays local, nothing sent to cloud
3. **Cost**: Free, no subscription needed
4. **Offline**: Works without internet after install
5. **Lower Latency**: Local execution is faster
6. **Real Browser**: Actual Chrome window vs cloud recording

---

## Questions Answered

### Q: Do they show a browser to you too?

**A: No.** Browserbase runs everything in the cloud. Users never see a local browser window. They only get a debug URL to watch a session recording on Browserbase's website.

### Q: Only in the VM and later session recording?

**A: Yes, exactly.** The browser runs in Browserbase's cloud VM. Users watch via session recording at the debug URL (like `https://browserbase.com/sessions/sess_xyz/debug`).

### Q: Maybe also download the code files so I can see it too?

**A: Done!** All files copied to `/Users/ashwin/agents-blocker/plugin/research/browserbase-plugin/`

---

## Recommendation for ContextFort

**Keep the local browser approach!** It's a key differentiator:

- **Enterprise compliance**: IT can see exactly what Claude is doing (browser visible on screen)
- **Trust & transparency**: Users see the browser, builds confidence
- **Debugging**: Users can interact with browser directly if needed
- **Privacy**: Data never leaves local machine

**Consider adding**:
1. **SessionStart hook** to pre-launch Chrome (eliminate first-use delay)
2. **SessionEnd hook** for automatic cleanup
3. **System messages** with clickable dashboard URL
4. **Auto-install** of Chrome for Testing if missing (already done!)

ContextFort's value prop: **"See what Claude sees, in real-time, on YOUR machine."**

Browserbase's value prop: **"Cloud-based, no local dependencies, but you never see the browser."**

Different use cases. ContextFort's is better for security-conscious enterprises that want visibility and control.
