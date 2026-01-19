# ContextFort Stage 1: Ephemeral Browser Isolation

**Version:** 1.0
**Date:** January 18, 2026
**Status:** Planning
**Target Market:** Fortune 500 Enterprises

---

## Executive Summary

ContextFort Stage 1 provides **enterprise-grade browser isolation for AI agents** through ephemeral, sandboxed Chrome instances. AI agents operate in completely fresh browser environments with zero access to existing user data, cookies, or credentials.

**Core Value Proposition:**
- ✅ **Zero Data Leakage:** Agents can't access your existing browser sessions
- ✅ **Complete Isolation:** Fresh Chrome instance for every agent session
- ✅ **Full Visibility:** Dashboard showing all agent activity
- ✅ **Automatic Cleanup:** All data deleted after session ends
- ✅ **Enterprise Ready:** SOC2 controls, audit logging, private deployment

**Scope (Stage 1):**
- Ephemeral Chrome isolation
- Agent activity monitoring
- Session recording and playback
- Dashboard for visibility
- Enterprise deployment via plugin marketplace

**Out of Scope (Future Stages):**
- Stage 2: Credential management, auto-login
- Stage 3: Remote browser integration

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Claude Code (CLI)                                       │
│  User: "Check my GitHub notifications"                  │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│  ContextFort Plugin (PreToolUse Hook)                   │
│  - Intercepts browser tool calls                        │
│  - Launches ephemeral Chrome                            │
│  - Registers session with dashboard                     │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│  Ephemeral Chrome Instance                              │
│  Location: /tmp/contextfort-[timestamp]                 │
│  - Fresh browser (no cookies, no history)               │
│  - ContextFort Extension installed                      │
│  - CDP enabled (port 9222)                              │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│  ContextFort Extension (Manifest V3)                    │
│  - Monitors all agent activity                          │
│  - Captures screenshots                                 │
│  - Tracks navigation                                    │
│  - Sends data to dashboard                              │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│  ContextFort Dashboard (localhost:8080)                 │
│  - Real-time session monitoring                         │
│  - Screenshot timeline                                  │
│  - Activity logs                                        │
│  - Session recordings                                   │
└─────────────────────────────────────────────────────────┘
```

---

## Components

### 1. ContextFort Claude Code Plugin

**Purpose:** Intercept browser commands and launch isolated Chrome

**Location:** `~/.claude/plugins/contextfort/`

**Structure:**
```
contextfort/
├── plugin.json              # Plugin metadata
├── hooks/
│   └── pre-tool-use.sh      # Intercepts browser tools
├── bin/
│   ├── launch-chrome.sh     # Launches ephemeral Chrome
│   ├── cleanup.sh           # Cleans up after session
│   └── install-extension.sh # Installs ContextFort extension
├── extension/
│   └── contextfort.crx      # Packed Chrome extension
└── config/
    └── settings.json        # Plugin configuration
```

**Key Files:**

#### `plugin.json`
```json
{
  "name": "contextfort",
  "version": "1.0.0",
  "description": "Enterprise browser isolation for AI agents",
  "publisher": "ContextFort",
  "hooks": {
    "PreToolUse": "./hooks/pre-tool-use.sh",
    "SessionEnd": "./hooks/session-end.sh"
  },
  "commands": {
    "status": "./bin/status.sh",
    "cleanup": "./bin/cleanup.sh"
  },
  "permissions": [
    "launch_processes",
    "file_system_temp",
    "network_localhost"
  ]
}
```

#### `hooks/pre-tool-use.sh`
```bash
#!/bin/bash
# Intercepts browser tool calls

TOOL_NAME="$1"
TOOL_PARAMS="$2"

# Detect browser-related tools
if [[ "$TOOL_NAME" =~ (chrome|browser|navigate|screenshot) ]]; then
    echo "[ContextFort] 🛡️ Browser tool detected: $TOOL_NAME"

    # Check if isolated Chrome is running
    if ! lsof -ti:9222 > /dev/null 2>&1; then
        echo "[ContextFort] 🚀 Launching isolated Chrome..."
        ~/.claude/plugins/contextfort/bin/launch-chrome.sh

        # Wait for Chrome to be ready
        sleep 3
    fi

    # Log the tool call
    echo "[ContextFort] ✅ Tool call allowed in isolated environment"

    # Allow the tool to proceed (exit 0)
    exit 0
fi

# Not a browser tool, allow normally
exit 0
```

#### `bin/launch-chrome.sh`
```bash
#!/bin/bash
# Launches ephemeral Chrome instance

# Generate unique session ID
SESSION_ID=$(date +%s)
PROFILE_DIR="/tmp/contextfort-${SESSION_ID}"
LOG_FILE="$HOME/.contextfort/sessions/${SESSION_ID}.log"

# Create directories
mkdir -p "$PROFILE_DIR"
mkdir -p "$HOME/.contextfort/sessions"

echo "[ContextFort] Session ID: ${SESSION_ID}" | tee "$LOG_FILE"
echo "[ContextFort] Profile: ${PROFILE_DIR}" | tee -a "$LOG_FILE"

# Install ContextFort extension in the ephemeral profile
EXTENSION_DIR="$HOME/.claude/plugins/contextfort/extension"
cp -r "$EXTENSION_DIR" "$PROFILE_DIR/Extensions/contextfort"

# Launch Chrome with isolated profile
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    --user-data-dir="$PROFILE_DIR" \
    --remote-debugging-port=9222 \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-networking \
    --disable-sync \
    --disable-translate \
    --load-extension="$PROFILE_DIR/Extensions/contextfort" \
    --window-size=1920,1080 \
    &

CHROME_PID=$!

# Save session metadata
cat > "$HOME/.contextfort/sessions/${SESSION_ID}.json" <<EOF
{
  "session_id": "${SESSION_ID}",
  "profile_dir": "${PROFILE_DIR}",
  "chrome_pid": ${CHROME_PID},
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "active"
}
EOF

# Register cleanup handler
echo "$CHROME_PID" > "/tmp/contextfort-${SESSION_ID}.pid"
echo "$PROFILE_DIR" > "/tmp/contextfort-${SESSION_ID}.path"

# Notify dashboard
curl -X POST http://localhost:8080/api/sessions \
    -H "Content-Type: application/json" \
    -d @"$HOME/.contextfort/sessions/${SESSION_ID}.json" \
    2>/dev/null || echo "[ContextFort] ⚠️  Dashboard not running"

echo "[ContextFort] ✅ Isolated Chrome launched (PID: $CHROME_PID)"
```

#### `hooks/session-end.sh`
```bash
#!/bin/bash
# Cleanup when session ends

echo "[ContextFort] 🧹 Cleaning up sessions..."

# Find all active sessions
for pid_file in /tmp/contextfort-*.pid; do
    if [ -f "$pid_file" ]; then
        PID=$(cat "$pid_file")

        # Check if process is still running
        if ! ps -p "$PID" > /dev/null 2>&1; then
            # Process ended, cleanup
            SESSION_ID=$(basename "$pid_file" .pid | sed 's/contextfort-//')
            PROFILE_DIR=$(cat "/tmp/contextfort-${SESSION_ID}.path" 2>/dev/null)

            if [ -n "$PROFILE_DIR" ] && [ -d "$PROFILE_DIR" ]; then
                echo "[ContextFort] 🗑️  Deleting: $PROFILE_DIR"
                rm -rf "$PROFILE_DIR"
            fi

            # Cleanup temp files
            rm -f "$pid_file"
            rm -f "/tmp/contextfort-${SESSION_ID}.path"

            # Update session metadata
            SESSION_FILE="$HOME/.contextfort/sessions/${SESSION_ID}.json"
            if [ -f "$SESSION_FILE" ]; then
                # Mark as ended
                jq '.status = "ended" | .ended_at = "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"' \
                    "$SESSION_FILE" > "${SESSION_FILE}.tmp"
                mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
            fi

            echo "[ContextFort] ✅ Session ${SESSION_ID} cleaned up"
        fi
    fi
done
```

---

### 2. ContextFort Chrome Extension

**Purpose:** Monitor agent activity and send data to dashboard

**Manifest V3 Extension Structure:**
```
extension/
├── manifest.json
├── background.js      # Service worker
├── content.js         # Injected into pages
├── popup.html         # Extension popup
├── dashboard.html     # Opens full dashboard
└── icon128.png
```

#### `manifest.json`
```json
{
  "manifest_version": 3,
  "name": "ContextFort Agent Monitor",
  "version": "1.0.0",
  "description": "Monitors AI agent browser activity",
  "permissions": [
    "storage",
    "tabs",
    "webNavigation",
    "scripting"
  ],
  "host_permissions": [
    "<all_urls>"
  ],
  "background": {
    "service_worker": "background.js"
  },
  "content_scripts": [{
    "matches": ["<all_urls>"],
    "js": ["content.js"],
    "run_at": "document_start"
  }],
  "action": {
    "default_popup": "popup.html",
    "default_icon": "icon128.png"
  }
}
```

#### `background.js`
```javascript
// Service worker for monitoring

const DASHBOARD_URL = 'http://localhost:8080';
let sessionId = null;

// Initialize session ID from storage
chrome.storage.local.get(['sessionId'], (result) => {
  sessionId = result.sessionId || Date.now().toString();
  chrome.storage.local.set({ sessionId });
});

// Monitor navigation
chrome.webNavigation.onBeforeNavigate.addListener((details) => {
  if (details.frameId === 0) { // Main frame only
    logEvent({
      type: 'navigation',
      url: details.url,
      timestamp: Date.now()
    });
  }
});

// Monitor tab creation
chrome.tabs.onCreated.addListener((tab) => {
  logEvent({
    type: 'tab_created',
    tabId: tab.id,
    url: tab.url,
    timestamp: Date.now()
  });
});

// Capture screenshots on navigation complete
chrome.webNavigation.onCompleted.addListener((details) => {
  if (details.frameId === 0) {
    chrome.tabs.captureVisibleTab(details.tabId, { format: 'png' }, (dataUrl) => {
      logEvent({
        type: 'screenshot',
        url: details.url,
        screenshot: dataUrl,
        timestamp: Date.now()
      });
    });
  }
});

// Log events to dashboard
async function logEvent(event) {
  event.sessionId = sessionId;

  try {
    await fetch(`${DASHBOARD_URL}/api/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(event)
    });
  } catch (error) {
    console.error('[ContextFort] Failed to log event:', error);
  }
}
```

---

### 3. ContextFort Dashboard

**Purpose:** Real-time monitoring and session management

**Technology Stack:**
- Next.js 15 (React 19)
- TypeScript
- TailwindCSS
- SQLite (local storage)

**Features:**
- Real-time session monitoring
- Screenshot timeline
- Activity logs
- Session recordings
- Export/reporting

**API Endpoints:**
```
POST   /api/sessions       # Create new session
GET    /api/sessions       # List all sessions
GET    /api/sessions/:id   # Get session details
POST   /api/events         # Log event
GET    /api/events/:sessionId # Get session events
DELETE /api/sessions/:id   # Delete session data
```

---

## Enterprise Features (Stage 1)

### Security

**1. Isolation Guarantees:**
- Each agent session runs in completely fresh Chrome instance
- Zero access to existing user data
- Separate temp directory per session
- Automatic cleanup on exit

**2. Audit Logging:**
```json
{
  "event_id": "evt_123",
  "session_id": "1705449600",
  "timestamp": "2026-01-18T10:30:00Z",
  "event_type": "navigation",
  "url": "https://github.com/company/repo",
  "user": "john.doe@company.com",
  "ip_address": "10.0.1.50"
}
```

**3. Access Controls:**
- Plugin requires IT installation approval
- Dashboard requires authentication
- Session data encrypted at rest

### Compliance

**SOC2 Type 2 Controls:**
- CC6.1: Logical access controls
- CC6.6: Audit logging
- CC7.2: Monitoring of system components

**HIPAA Readiness:**
- PHI never persists (ephemeral sessions)
- All data deleted after session
- Audit trail of all access

**GDPR Compliance:**
- Data minimization (only essential logs)
- Right to deletion (automatic cleanup)
- Data processing transparency

### Deployment

**Private Marketplace:**
```bash
# Company hosts plugin on internal GitHub
git clone git@github.company.com:security/contextfort-plugin.git

# IT deploys to internal marketplace
/plugin marketplace add github.company.com/security/plugins

# Users install approved version
/plugin install contextfort@company-security --version 1.0.0
```

**Configuration Management:**
```json
{
  "allowedUsers": ["john.doe@company.com", "jane.smith@company.com"],
  "maxSessionDuration": 3600,
  "screenshotInterval": 30,
  "retentionDays": 90,
  "dashboardUrl": "http://internal-dashboard.company.com:8080"
}
```

---

## Installation Guide

### For IT Administrators

**1. Obtain Plugin:**
```bash
git clone https://github.com/contextfort/claude-code-plugin.git
cd claude-code-plugin
```

**2. Configure:**
Edit `config/settings.json`:
```json
{
  "company": "ACME Corp",
  "dashboardUrl": "http://contextfort.acme.internal:8080",
  "ssoEnabled": false,
  "maxSessions": 5
}
```

**3. Deploy to Internal Marketplace:**
```bash
# Push to internal GitHub/GitLab
git remote add company git@github.company.com:security/contextfort.git
git push company main

# Add marketplace
/plugin marketplace add github.company.com/security/plugins \
  --token $GITHUB_ENTERPRISE_TOKEN
```

**4. Approve for Users:**
```bash
# In managed settings
{
  "allowedPlugins": [
    "github.company.com/security/plugins/contextfort"
  ]
}
```

### For End Users

**1. Install Plugin:**
```bash
# Add company marketplace (one-time)
/plugin marketplace add github.company.com/security/plugins

# Install ContextFort
/plugin install contextfort@company-security
```

**2. Verify Installation:**
```bash
/plugin list
# Should show: contextfort@1.0.0 (active)
```

**3. Use Normally:**
```bash
# Just use Claude Code as normal
claude "Check my GitHub notifications"

# ContextFort automatically provides isolation
```

---

## Success Metrics

### Technical KPIs:
- **Session Isolation:** 100% of agent sessions run in ephemeral browsers
- **Data Leakage:** 0 incidents of agent accessing user data
- **Cleanup Success:** 100% of temp directories deleted after session
- **Uptime:** 99.9% dashboard availability

### Business KPIs:
- **Enterprise Adoption:** 10 Fortune 500 companies by Q2 2026
- **Security Incidents:** 0 breaches attributable to ContextFort
- **User Satisfaction:** 4.5/5.0 rating from security teams

### Compliance KPIs:
- **SOC2 Type 2:** Achieved by Q3 2026
- **Audit Findings:** 0 critical findings
- **Incident Response:** <1 hour mean time to response

---

## Timeline

**Month 1 (February 2026):**
- Week 1-2: Build plugin core (hooks, launcher)
- Week 3-4: Build extension (monitoring)

**Month 2 (March 2026):**
- Week 1-2: Build dashboard (UI + API)
- Week 3-4: Integration testing, bug fixes

**Month 3 (April 2026):**
- Week 1-2: Security audit, penetration testing
- Week 3-4: Documentation, pilot with 2 companies

**Month 4 (May 2026):**
- General availability
- SOC2 Type 2 audit begins

---

## Risk Assessment

### Technical Risks:

**Risk 1: Chrome crashes/hangs**
- **Mitigation:** Timeout monitoring, automatic restart
- **Severity:** Medium

**Risk 2: Extension conflicts**
- **Mitigation:** Minimal permissions, isolated installation
- **Severity:** Low

**Risk 3: Dashboard unavailable**
- **Mitigation:** Local SQLite fallback, offline mode
- **Severity:** Low

### Business Risks:

**Risk 1: Enterprise adoption slow**
- **Mitigation:** Pilot program, case studies
- **Severity:** Medium

**Risk 2: Compliance certification delays**
- **Mitigation:** Engage auditors early, follow frameworks
- **Severity:** Medium

---

## Next Steps

1. **Build POC:** 2-week sprint for working prototype
2. **Enterprise Pilot:** 2 companies, 4-week test
3. **Security Audit:** External penetration test
4. **SOC2 Preparation:** Engage audit firm
5. **General Availability:** Q2 2026

---

**Status:** Ready to start implementation ✅
