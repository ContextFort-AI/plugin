# ContextFort: Enterprise Browser Isolation for AI Agents

**Tagline:** Secure AI agents at Fortune 500 scale

---

## What is ContextFort?

ContextFort provides **enterprise-grade browser isolation** for AI agents (Claude, ChatGPT, autonomous browser automation). Every agent session runs in a completely fresh, ephemeral browser instance with zero access to your existing data, cookies, or credentials.

**The Problem:**
AI agents running in your browser can access:
- All your existing cookies and sessions
- Your saved passwords
- Your browsing history
- Your personal data across all websites

**One malicious prompt could steal everything.**

**The Solution:**
ContextFort automatically isolates every agent session in a fresh, temporary browser that gets deleted after use.

---

## Three-Stage Product Vision

### Stage 1: Ephemeral Isolation (Available Q2 2026)
**Core isolation and monitoring**

```bash
# Install ContextFort plugin
/plugin install contextfort@enterprise

# Use Claude normally
claude "Check my GitHub notifications"

# ContextFort automatically:
✅ Launches fresh isolated Chrome (/tmp/contextfort-12345)
✅ Agent operates in complete isolation
✅ All activity logged to dashboard
✅ Session deleted after completion
```

**Key Features:**
- Ephemeral browser instances (nothing persists)
- Real-time activity monitoring
- Screenshot timeline and session recordings
- Audit logs for compliance
- Enterprise deployment (private marketplace)

**Agent handles authentication on its own (you provide credentials when asked)**

---

### Stage 2: Credential Management (Q3 2026)
**Eliminate credential exposure**

Integrates with enterprise credential tools:
- 1Password CLI
- Okta SSO
- CyberArk
- Azure AD

**Auto-login flow:**
```
Agent navigates to GitHub
    ↓
ContextFort detects login page
    ↓
Gets credentials from 1Password CLI
    ↓
Auto-fills and submits form
    ↓
Agent sees "already logged in" ✅
    ↓
Agent NEVER saw the password
```

**Key Features:**
- 1Password/CyberArk integration
- Okta SSO session management
- TOTP 2FA automation
- Credential approval workflows
- Usage audit logs

---

### Stage 3: Remote Browsers (Q4 2026)
**Physical airgap and maximum security**

Routes agents to cloud browsers:
- Browserbase
- Self-hosted Kubernetes
- AWS Lambda + Chromium

**Benefits:**
- Browser never runs on employee laptop
- Physical network isolation
- HIPAA/SOC2 compliance checkbox
- Centralized org-wide monitoring

---

## Architecture (Stage 1)

```
┌────────────────────────────────────────────┐
│  Claude Code (Your existing setup)          │
└────────────────────────────────────────────┘
                ↓
┌────────────────────────────────────────────┐
│  ContextFort Plugin (Auto-intercepts)       │
│  - Detects browser commands                 │
│  - Launches isolated Chrome                 │
└────────────────────────────────────────────┘
                ↓
┌────────────────────────────────────────────┐
│  Ephemeral Chrome                           │
│  /tmp/contextfort-1705449600                │
│  - Fresh (no cookies, no history)           │
│  - ContextFort Extension installed          │
│  - Monitoring enabled                       │
└────────────────────────────────────────────┘
                ↓
┌────────────────────────────────────────────┐
│  ContextFort Dashboard (localhost:8080)     │
│  - Real-time session monitoring             │
│  - Screenshot timeline                      │
│  - Activity logs                            │
│  - Session recordings                       │
└────────────────────────────────────────────┘
```

---

## Enterprise Features

### Security
- **SOC2 Type 2** certified processes
- **Zero trust** architecture (every session isolated)
- **Audit logging** (all agent activity recorded)
- **Access controls** (role-based permissions)
- **Encryption** (data at rest and in transit)

### Compliance
- **HIPAA** ready (PHI never persists)
- **GDPR** compliant (data minimization, automatic deletion)
- **ISO 27001** controls implemented
- **Industry certifications** (finance, healthcare)

### Deployment
- **Private marketplace** (host on internal GitHub/GitLab)
- **SSO integration** (Okta, Azure AD)
- **Centralized management** (IT controls versions and policies)
- **Automatic updates** (controlled rollout)
- **Multi-tenant** (department isolation)

### Support
- **Enterprise SLAs** (99.9% uptime guarantee)
- **Dedicated support** (24/7 for critical issues)
- **Professional services** (deployment, training, customization)
- **Account management** (CSM for enterprise accounts)

---

## Installation

### For IT Administrators

**1. Deploy to Internal Marketplace:**
```bash
# Clone ContextFort plugin
git clone https://github.com/contextfort/claude-code-plugin.git

# Push to internal repo
git remote add company git@github.company.com:security/contextfort.git
git push company main

# Configure marketplace
/plugin marketplace add github.company.com/security/plugins \
  --token $GITHUB_ENTERPRISE_TOKEN
```

**2. Configure Settings:**
Edit `config/settings.json`:
```json
{
  "company": "ACME Corp",
  "dashboardUrl": "http://contextfort.acme.internal:8080",
  "maxSessionDuration": 3600,
  "retentionDays": 90,
  "allowedUsers": ["*@acme.com"]
}
```

**3. Approve for Users:**
```json
{
  "allowedPlugins": [
    "github.company.com/security/plugins/contextfort"
  ]
}
```

### For End Users

**1. Install Plugin:**
```bash
# Add company marketplace
/plugin marketplace add github.company.com/security/plugins

# Install ContextFort
/plugin install contextfort@company-security
```

**2. Use Normally:**
```bash
# Just use Claude Code as always
claude "Check my GitHub notifications"

# ContextFort provides automatic isolation
```

---

## Comparison

| Feature | No ContextFort | ContextFort Stage 1 | ContextFort Stage 2 | ContextFort Stage 3 |
|---------|----------------|---------------------|---------------------|---------------------|
| **Agent accesses your cookies** | ❌ Yes | ✅ No | ✅ No | ✅ No |
| **Agent sees your passwords** | ❌ Yes | ⚠️ If you type them | ✅ No | ✅ No |
| **Browser isolation** | ❌ None | ✅ Local ephemeral | ✅ Local ephemeral | ✅ Remote cloud |
| **Activity monitoring** | ❌ None | ✅ Full dashboard | ✅ Full dashboard | ✅ Full dashboard |
| **Audit logs** | ❌ None | ✅ Complete | ✅ Complete | ✅ Complete |
| **Auto-login** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **2FA automation** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Physical airgap** | ❌ No | ❌ No | ❌ No | ✅ Yes |
| **Compliance ready** | ❌ No | ⚠️ Partial | ✅ Yes | ✅ Maximum |

---

## Documentation

**Core Documents:**
- [`LEARNINGS.md`](./LEARNINGS.md) - Technical architecture and discoveries
- [`JOURNAL.md`](./JOURNAL.md) - Development diary and decision log
- [`STAGE1_PLAN.md`](./STAGE1_PLAN.md) - Detailed Stage 1 specification

**Coming Soon:**
- `STAGE2_PLAN.md` - Credential management design
- `STAGE3_PLAN.md` - Remote browser integration
- `SECURITY.md` - Security architecture
- `COMPLIANCE.md` - Compliance documentation

---

## Roadmap

**Q1 2026:**
- ✅ Architecture design complete
- 🔄 Stage 1 development starts

**Q2 2026:**
- Stage 1 beta (2 enterprise pilots)
- Stage 1 general availability
- SOC2 Type 2 audit begins

**Q3 2026:**
- Stage 2 development (credential management)
- SOC2 Type 2 certification complete
- 10 Fortune 500 customers

**Q4 2026:**
- Stage 2 general availability
- Stage 3 development (remote browsers)
- ISO 27001 certification

**Q1 2027:**
- Stage 3 general availability
- Industry-specific certifications (HIPAA, PCI-DSS)
- 50 Fortune 500 customers

---

## Target Market

**Primary:** Fortune 500 enterprises
- Financial services
- Healthcare
- Government/defense
- Legal
- Technology

**Requirements:**
- SOC2 Type 2 certified
- HIPAA compliant (healthcare)
- PCI-DSS compliant (finance)
- ISO 27001 certified
- On-premise deployment option
- Enterprise SSO integration
- 99.9% uptime SLA

---

## Pricing (Preliminary)

**Stage 1: Ephemeral Isolation**
- $50/user/month (annual contract)
- Minimum 100 users
- Includes: Plugin, dashboard, support

**Stage 2: + Credential Management**
- $75/user/month (annual contract)
- Includes: Everything in Stage 1 + auto-login + 2FA

**Stage 3: + Remote Browsers**
- $100/user/month (annual contract)
- Includes: Everything in Stage 2 + remote browsers

**Enterprise:**
- Custom pricing
- Volume discounts
- Professional services
- Dedicated support

---

## Contact

**Website:** https://contextfort.com (TBD)
**Email:** enterprise@contextfort.com (TBD)
**GitHub:** https://github.com/contextfort (TBD)

**For pilot program:** pilot@contextfort.com

---

**Status:** Stage 1 in development - Q2 2026 availability
