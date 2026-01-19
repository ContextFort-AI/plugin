# ContextFort Architecture Learnings

**Date Started:** 2026-01-18
**Goal:** Enterprise-grade browser isolation for AI agents (Fortune 500 focus)

---

## Key Discoveries

### 1. How Claude Desktop + Chrome Works

```
Claude Desktop App
    ↓ (via Unix Socket)
Native Messaging Host (Rust binary)
    - Path: /Applications/Claude.app/Contents/Helpers/chrome-native-host
    - Purpose: MESSAGE BROKER ONLY (stdin/stdout ↔ Unix Socket)
    - Does NOT launch Chrome
    - Does NOT control profiles
    - Does NOT use CDP
    ↓ (via stdin/stdout)
Chrome Extension (MCP Server)
    - ID: fcoeoabgfenejglbffodgkkbkcdhcgfn
    - Provides 19 browser tools via MCP protocol
    - Uses Chrome Extension API (chrome.tabs, chrome.windows, etc.)
    ↓
Existing Chrome Instance (whatever profile is already open)
    - Native host connects to ALREADY RUNNING Chrome
    - Uses CURRENT PROFILE with all its cookies/credentials
```

**Critical Insight:** Native host is just a message pipe. It doesn't provide isolation!

---

### 2. Profile Isolation Reality

#### What `chrome.windows.create()` Actually Does:
```javascript
chrome.windows.create({ url: 'https://github.com' })
```

**Result:**
- ✅ NEW WINDOW (visual separation only)
- ❌ SAME PROFILE (same cookies, localStorage, credentials)
- ❌ NOT SANDBOXED (agent has access to everything)

**All windows in same profile share:**
- Cookies
- LocalStorage
- SessionStorage
- IndexedDB
- Saved passwords
- Browsing history

#### True Isolation Requires:
```bash
# Different user-data-dir = different profile = true isolation
chrome --user-data-dir=/tmp/isolated-instance
```

**BUT:** Chrome Extension API CANNOT launch new Chrome processes!

---

### 3. "Profileless" Chrome Concept (User's Insight!)

**The Breakthrough:** We don't need "profiles" - we need EPHEMERAL temp directories!

```bash
# This is effectively "no profile" / "profileless" Chrome
chrome --user-data-dir=/tmp/contextfort-$(date +%s) \
       --remote-debugging-port=9222 \
       --no-first-run

# Result:
# - Fresh Chrome with NOTHING
# - No cookies, no history, no saved passwords
# - Directory deleted after session
# - TRUE ephemeral isolation
```

---

### 4. Claude Code Plugin System

#### Hook Types:
- **PreToolUse**: Runs before tool execution (can block)
- **PostToolUse**: Runs after tool completion
- **Notification**: Runs on notifications
- **SessionStart**: Runs on session start
- **Stop**: Runs when Claude finishes

#### Plugin Architecture:
```
~/.claude/plugins/contextfort/
├── plugin.json          # Plugin metadata
├── hooks/
│   └── pre-tool-use.sh  # Intercepts browser tools
└── bin/
    └── launch-chrome.sh # Launches isolated Chrome
```

#### Current Status:
- **Feature Request (#15188, #15125):** Direct profile control not yet available
- **Workaround:** Use PreToolUse hook to intercept and launch our own Chrome

---

### 5. Paul Klein's Browserbase Plugin

**Command:**
```bash
/plugin marketplace add browserbase/claude-code-plugin
/plugin install browserbase@browserbase-cloud
```

**What it does:**
- Routes browser commands to Browserbase cloud
- Claude thinks it's using local Chrome
- Actually uses remote browser

**Architecture (from Paul Klein's reverse engineering):**
```
Claude Code
    ↓ (sends browser tool request)
Browserbase Plugin (intercepts)
    ↓ (translates to CDP)
Browserbase Cloud (remote Chrome)
```

---

## ContextFort Three-Stage Roadmap

### Stage 1: Ephemeral Browser Isolation (CORE PRODUCT)
**Timeline:** Q1-Q2 2026
**Target:** Fortune 500 enterprises requiring data isolation

**Components:**
1. Claude Code Plugin (PreToolUse hooks)
2. Ephemeral Chrome launcher (/tmp/contextfort-*)
3. ContextFort Extension (activity monitoring)
4. Dashboard (real-time visibility, session recordings)

**Flow:**
```
Claude tries browser → Hook intercepts → Launch /tmp/fresh-chrome (empty)
→ Agent operates in isolation → All activity logged → Session ends → Delete everything
```

**Value Delivered:**
- ✅ Zero data leakage (agent can't access existing sessions)
- ✅ Complete isolation (fresh browser every time)
- ✅ Full visibility (dashboard shows all activity)
- ✅ Automatic cleanup (nothing persists)
- ✅ Enterprise controls (audit logs, access controls)

**Scope:**
- ✅ Isolation and sandboxing
- ✅ Activity monitoring
- ✅ Session management
- ❌ NO credential management (agent handles auth on its own)
- ❌ NO auto-login features

---

### Stage 2: Credential Management (ENTERPRISE ADD-ON)
**Timeline:** Q3 2026
**Target:** Enterprises wanting to eliminate credential exposure

**New Components:**
1. 1Password CLI integration
2. Okta SSO session management
3. TOTP generation engine
4. Auto-login orchestration
5. Credential vault UI

**Flow:**
```
Agent navigates to site → ContextFort detects login page
→ Checks 1Password/Okta for credentials → Auto-fills and submits
→ Agent sees "already logged in" → Agent never touches credentials
```

**Value Added:**
- ✅ Eliminate credential exposure to agents
- ✅ Integrate with existing enterprise tools (1Password, Okta)
- ✅ TOTP 2FA automation
- ✅ SSO session leveraging
- ✅ Centralized credential policies

**Scope:**
- ✅ Password manager integration (1Password CLI, CyberArk API)
- ✅ SSO integration (Okta, Azure AD session cookies)
- ✅ TOTP generation and auto-fill
- ✅ Credential approval workflows
- ✅ Credential usage audit logs

---

### Stage 3: Remote Browser Integration (MAXIMUM SECURITY)
**Timeline:** Q4 2026 - Q1 2027
**Target:** Highly regulated industries, compliance requirements

**New Components:**
1. Browserbase adapter
2. Self-hosted remote browser support
3. AWS Lambda + Chromium templates
4. Remote session recorder
5. Compliance reporting engine

**Flow:**
```
Claude tries browser → ContextFort Plugin → Route to cloud
→ Browser runs in Browserbase/AWS → Physical airgap from local machine
→ Zero local data access → Full compliance documentation
```

**Value Added:**
- ✅ Physical airgap (browser never on employee laptop)
- ✅ Compliance checkbox (HIPAA, SOC2, ISO 27001)
- ✅ Centralized monitoring across organization
- ✅ Reduced endpoint risk
- ✅ Cloud-native scalability

**Scope:**
- ✅ Browserbase cloud integration
- ✅ Self-hosted remote browser templates (Docker, Kubernetes)
- ✅ AWS Lambda Chromium deployment
- ✅ Remote session recording and playback
- ✅ Compliance reporting (SOC2, HIPAA audit trails)

---

## Enterprise 2FA/Credential Management ✅

### How Fortune 500 Handle 2FA with Automation:

**1Password Enterprise:**
- **CLI Integration**: `op` command-line tool
- **TOTP Generation**: Store TOTP secrets, generate codes programmatically
- **API Access**: Programmatic credential retrieval
- **SSO Integration**: Works with Okta, Azure AD

```bash
# 1Password CLI - Get TOTP code
op item get "GitHub" --otp
# Output: 123456

# Get credentials
op item get "GitHub" --fields username,password
```

**Okta Enterprise:**
- **SAML/SSO**: Single sign-on for web apps
- **Session Management**: Persistent sessions via cookies
- **MFA Policies**: Adaptive authentication (trust device, network)
- **API Access**: Programmatic authentication

**Enterprise 2FA Automation Landscape:**
- 87% of companies 10,000+ employees use MFA
- Challenge: Some services don't expose TOTP secrets
- Solution: Enterprises use credential vaults (1Password, CyberArk, HashiCorp Vault)
- Trend: Moving to passwordless (FIDO2, WebAuthn)

### ContextFort Enterprise Approach:

**Stage 1: TOTP + Password Manager Integration**
```javascript
// ContextFort integrates with:
- 1Password CLI (read-only access to team vaults)
- Okta session cookies (leverage existing SSO)
- TOTP generation (stored secrets, 6-digit codes)
```

**Stage 2: SSO/SAML Integration**
- Agent uses existing Okta/Azure AD sessions
- No password storage needed
- ContextFort just manages session cookies

---

## Plugin Marketplace ✅ MAINSTREAM!

### Installation Flow:
```bash
# Add marketplace (can be private GitHub repo)
/plugin marketplace add your-org/plugins

# Install plugin
/plugin install contextfort@your-org

# Update marketplace
/plugin marketplace update
```

### Enterprise Distribution:

**Official Anthropic Marketplace:**
- https://github.com/anthropics/claude-plugins-official
- High-quality vetted plugins

**Private Enterprise Marketplace:**
- Host on private GitHub/GitLab
- Use authentication tokens for private repos
- Centralized version control
- Automatic updates

**Security Controls:**
```json
{
  "strictKnownMarketplaces": true,
  "allowlist": {
    "github.com/your-org/plugins": {
      "allowed_repos": ["contextfort-plugin"],
      "required_ref": "main"
    }
  }
}
```

### Browserbase Plugin Example:

**Installation:**
```bash
/plugin marketplace add browserbase/claude-code-plugin
/plugin install browserbase@browserbase-cloud
```

**How It Works:**
```
Claude Code
    ↓ (MCP browser command)
Browserbase Plugin (intercepts via socket forwarding)
    ↓ (Unix Socket: /tmp/claude-mcp-browser-bridge-*)
Forwarding Server
    ↓ (WebSocket/HTTP)
Browserbase Cloud Browser (CDP)
```

**Key Insight:** Plugin hijacks the MCP browser bridge socket!

---

### 3. Compliance Requirements
- SOC2 Type 2 requirements
- HIPAA data handling
- ISO 27001 controls
- Audit logging needs

---

## Technical Decisions Made

### ✅ Confirmed Approaches:
1. **Use Claude Code Plugin System** (hooks for interception)
2. **Ephemeral temp directories** (not persistent profiles)
3. **Credential injection** (agent never sees passwords)
4. **Two-stage rollout** (local first, remote later)

### ❌ Rejected Approaches:
1. Chrome Extension only (can't create true isolation)
2. Window-based isolation (same profile = no isolation)
3. Native messaging host (just for message passing)
4. Incognito mode (can't move tabs, limited extension support)

---

## Next Steps

1. Document enterprise 2FA landscape
2. Investigate plugin marketplace and distribution
3. Build Stage 1 MVP:
   - Claude Code plugin
   - Ephemeral Chrome launcher
   - ContextFort extension
   - Credential dashboard
4. Test with Fortune 500 requirements

---

## References

- Claude Code Hooks: https://code.claude.com/docs/en/hooks-guide
- GitHub Issue #15188: Chrome profile selection
- GitHub Issue #15125: Target specific Chrome instances
- Paul Klein's reverse engineering: https://x.com/pk_iv/status/2005694082627297735
- Browserbase plugin example
