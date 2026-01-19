# ContextFort Claude Code Plugin

**Enterprise browser isolation for AI agents**

Version: 1.0.0

---

## What This Plugin Does

ContextFort automatically isolates every AI agent browser session in a fresh, ephemeral Chrome instance. The agent operates in a completely clean environment with:

- ✅ **No access to your existing cookies**
- ✅ **No access to your browsing history**
- ✅ **No access to your saved passwords**
- ✅ **Complete isolation from your work browser**
- ✅ **Automatic cleanup after session ends**

## Features

### Stage 1 (Current)
- **Ephemeral Browser Instances** - Fresh /tmp/ profile for each session
- **Automatic Interception** - PreToolUse hook catches all browser commands
- **Activity Monitoring** - Extension tracks all agent actions
- **Session Management** - Dashboard shows real-time activity
- **Audit Logging** - Complete record for compliance

### Coming Soon
- **Stage 2:** Credential management (1Password, Okta integration)
- **Stage 3:** Remote browser support (Browserbase, self-hosted)

---

## Installation

### Prerequisites

- macOS or Linux
- Google Chrome installed
- Claude Code installed
- Node.js 18+ (for dashboard)

### Step 1: Install Plugin

```bash
# Clone or download this repository
cd /path/to/contextfort-plugin

# Install to Claude plugins directory
cp -r ./contextfort ~/.claude/plugins/

# Verify installation
ls -la ~/.claude/plugins/contextfort
```

### Step 2: Start Dashboard

```bash
cd /path/to/contextfort-dashboard
npm install
npm run dev

# Dashboard will start on http://localhost:8080
```

### Step 3: Test Installation

```bash
# In Claude Code, check status
/contextfort status

# You should see:
# ✅ Plugin installed
# ⚠️  Isolated Chrome: Not running (will start automatically)
# ✅ Dashboard: Running
```

---

## Usage

### Basic Usage

Just use Claude Code normally! ContextFort works automatically.

```bash
# Example: Agent will run in isolated browser
claude "Check my GitHub notifications"

# ContextFort automatically:
# 1. Detects browser command
# 2. Launches isolated Chrome (/tmp/contextfort-1705449600)
# 3. Agent operates in isolation
# 4. Session logged to dashboard
# 5. Profile deleted after session ends
```

### View Dashboard

```bash
/contextfort dashboard

# Or manually open:
open http://localhost:8080
```

### Check Status

```bash
/contextfort status

# Shows:
# - Active sessions
# - Chrome status
# - Dashboard status
# - Recent sessions
```

### Manual Cleanup

```bash
/contextfort cleanup

# Force cleanup of all sessions
# (normally happens automatically)
```

---

## How It Works

### Architecture

```
Claude Code
    ↓
PreToolUse Hook (intercepts browser commands)
    ↓
Launch Isolated Chrome (/tmp/contextfort-[timestamp])
    ↓
ContextFort Extension (monitors activity)
    ↓
Dashboard API (records events)
    ↓
Automatic Cleanup (delete profile after session)
```

### Session Lifecycle

1. **Detection:** Hook detects browser tool call (navigate, screenshot, etc.)
2. **Launch:** Fresh Chrome instance created in /tmp/ directory
3. **Monitoring:** Extension tracks all agent activity
4. **Logging:** Events sent to dashboard API
5. **Cleanup:** Profile deleted when Chrome exits

### Data Storage

**Ephemeral (deleted after session):**
- /tmp/contextfort-[session-id]/ - Chrome profile directory
- Includes: cookies, localStorage, history, cache

**Persistent (kept for audit):**
- ~/.contextfort/sessions/[session-id].json - Session metadata
- ~/.contextfort/logs/ - Plugin logs
- Dashboard database - Events, screenshots, activity logs

**Retention:** 90 days (configurable)

---

## Configuration

Edit `~/.claude/plugins/contextfort/config/settings.json`:

```json
{
  "dashboardUrl": "http://localhost:8080",
  "maxSessionDuration": 3600,
  "screenshotInterval": 30,
  "retentionDays": 90,
  "autoCleanup": true,
  "logLevel": "info"
}
```

---

## Dashboard

### Features

- **Real-time Sessions:** See active agent sessions
- **Screenshot Timeline:** Visual record of agent actions
- **Activity Log:** All navigation, clicks, inputs
- **Session Replay:** Playback of agent sessions
- **Export:** Download session data for compliance

### API Endpoints

```
GET    /health                   - Health check
GET    /api/sessions             - List all sessions
GET    /api/sessions/:id         - Get session details
POST   /api/sessions             - Create session (plugin)
POST   /api/events               - Log event (extension)
GET    /api/events/:sessionId    - Get session events
POST   /api/cleanup              - Log cleanup event
```

---

## Troubleshooting

### Chrome doesn't start

**Problem:** Hook intercepts but Chrome doesn't launch

**Solutions:**
1. Check Chrome is installed: `which google-chrome` or check /Applications/
2. Check logs: `cat ~/.contextfort/logs/launch.log`
3. Try manual launch: `~/.claude/plugins/contextfort/bin/launch-chrome.sh`

### Dashboard not connecting

**Problem:** Extension can't reach dashboard

**Solutions:**
1. Check dashboard is running: `curl http://localhost:8080/health`
2. Start dashboard: `cd contextfort-dashboard && npm run dev`
3. Check firewall settings (allow localhost:8080)

### Sessions not cleaning up

**Problem:** /tmp/ directories accumulating

**Solutions:**
1. Run manual cleanup: `/contextfort cleanup`
2. Check SessionEnd hook: `cat ~/.contextfort/logs/cleanup.log`
3. Verify cleanup on reboot: `/tmp/` clears automatically on macOS/Linux

### Extension not loading

**Problem:** ContextFort extension not visible in Chrome

**Solutions:**
1. Check extension directory: `ls ~/.claude/plugins/contextfort/extension/`
2. Load manually: Chrome → Extensions → Load Unpacked → select extension dir
3. Check Chrome version: Need 120+ for Manifest V3

---

## Security & Compliance

### Security Features

- **Process Isolation:** Each session in separate OS process
- **Data Isolation:** No shared cookies, storage, or cache
- **Automatic Cleanup:** All data deleted after session
- **Audit Logging:** Complete activity trail
- **Access Controls:** Plugin requires installation approval

### Compliance

- **SOC2 Type 2:** In progress (Q2 2026)
- **HIPAA Ready:** No PHI persists (ephemeral sessions)
- **GDPR Compliant:** Data minimization, automatic deletion
- **Audit Trail:** 90-day retention of session metadata

---

## Enterprise Deployment

### Private Marketplace

Host on internal GitHub/GitLab:

```bash
# Clone to internal repo
git clone https://github.com/contextfort/claude-code-plugin.git
git remote add company git@github.company.com:security/contextfort.git
git push company main

# Users install via
/plugin marketplace add github.company.com/security/plugins
/plugin install contextfort@company-security
```

### Configuration Management

Centralized config via managed settings:

```json
{
  "plugins": {
    "contextfort": {
      "dashboardUrl": "http://contextfort.company.internal:8080",
      "maxSessionDuration": 7200,
      "retentionDays": 365,
      "allowedUsers": ["*@company.com"]
    }
  }
}
```

---

## Development

### Project Structure

```
contextfort/
├── plugin.json              # Plugin metadata
├── hooks/
│   ├── pre-tool-use.sh      # Intercepts browser tools
│   └── session-end.sh       # Cleanup on session end
├── bin/
│   ├── launch-chrome.sh     # Launches isolated Chrome
│   ├── status.sh            # Check status
│   ├── cleanup.sh           # Manual cleanup
│   └── dashboard.sh         # Open dashboard
├── extension/               # Chrome extension
│   ├── manifest.json
│   ├── background.js
│   ├── content.js
│   └── dashboard-connector.js
├── config/
│   └── settings.json        # Configuration
└── README.md               # This file
```

### Testing

```bash
# Test hook
~/.claude/plugins/contextfort/hooks/pre-tool-use.sh "mcp__claude-in-chrome__navigate" "{}"

# Test launcher
~/.claude/plugins/contextfort/bin/launch-chrome.sh

# Test cleanup
~/.claude/plugins/contextfort/bin/cleanup.sh

# Check status
~/.claude/plugins/contextfort/bin/status.sh
```

---

## Support

**Documentation:** See `/Users/ashwin/agents-blocker/` for full docs
**Issues:** [GitHub Issues](https://github.com/contextfort/claude-code-plugin/issues) (TBD)
**Email:** support@contextfort.com (TBD)

---

## License

MIT License - See LICENSE file

---

## Changelog

### 1.0.0 (2026-01-18)
- Initial release
- Ephemeral browser isolation
- Activity monitoring
- Dashboard integration
- Enterprise deployment support

---

**Status:** Stage 1 Complete ✅
**Next:** Stage 2 (Credential Management) - Q3 2026
