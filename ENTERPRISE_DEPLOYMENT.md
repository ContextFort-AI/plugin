# ContextFort Enterprise Deployment Guide

**For Fortune 500 Companies**

## Overview

ContextFort provides enterprise browser isolation for Claude Desktop and Claude Code, giving IT departments complete visibility and control over AI-assisted browser automation.

## Deployment Architecture

### Components

1. **ContextFort Chrome** - Isolated Chrome for Testing instance
2. **Native Messaging Proxy** - Intercepts Claude-in-Chrome communications
3. **ContextFort Extension** - Monitors and logs all browser activity
4. **Chrome for Testing Binary** - Self-contained browser (~170MB)

### Installation Footprint

```
~/.contextfort/                          # User data directory
  ├── logs/                             # Activity logs
  │   ├── native-proxy.log              # Proxy intercepts
  │   └── chrome-*.log                  # Browser logs
  ├── profile-template/                 # (Optional) Persistent auth
  └── (ephemeral sessions deleted)

~/agents-blocker/plugin/                 # Installation directory
  ├── bin/                              # Scripts and proxy
  │   ├── native-messaging-proxy.js    # Main proxy
  │   ├── launch-chrome.sh             # Chrome launcher
  │   └── install-native-proxy.sh      # Installer
  ├── chrome/                           # Chrome for Testing binary
  ├── extension/                        # ContextFort extension
  └── NATIVE_MESSAGING.md              # Documentation

~/Library/Application Support/Google/Chrome/NativeMessagingHosts/
  └── com.anthropic.claude_browser_extension.json  # Proxy config
```

---

## Fortune 500 Deployment Methods

### Method 1: MDM Deployment (Recommended)

**Platforms:** Jamf Pro, Microsoft Intune, VMware Workspace ONE

#### Step 1: Create Installation Package

```bash
# Build deployment package
cd /path/to/contextfort-plugin

# Create installer
./scripts/build-enterprise-installer.sh

# Generates: ContextFort-Enterprise.pkg (for macOS)
```

#### Step 2: Configure MDM Policy

**Jamf Pro Example:**

```xml
<!-- Jamf Configuration Profile -->
<?xml version="1.0" encoding="UTF-8"?>
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.ManagedClient.preferences</string>
            <key>PayloadUUID</key>
            <string>CONTEXTFORT-UUID</string>
            <key>PayloadIdentifier</key>
            <string>com.contextfort.config</string>
            <key>PayloadVersion</key>
            <integer>1</integer>

            <!-- Environment Variables -->
            <key>environment</key>
            <dict>
                <key>CONTEXTFORT_PLUGIN_DIR</key>
                <string>/usr/local/contextfort</string>
                <key>CONTEXTFORT_ENTERPRISE_MODE</key>
                <string>true</string>
                <key>CONTEXTFORT_AUDIT_LEVEL</key>
                <string>full</string>
            </dict>
        </dict>
    </array>
</dict>
```

**Intune PowerShell Example (Windows):**

```powershell
# Install ContextFort via Intune
$installPath = "C:\Program Files\ContextFort"
$proxyScript = "$installPath\bin\native-messaging-proxy.js"

# Install Node.js (prerequisite)
winget install OpenJS.NodeJS

# Extract package
Expand-Archive -Path "ContextFort-Enterprise.zip" -DestinationPath $installPath

# Run installer
& "$installPath\bin\install-native-proxy.sh"

# Verify installation
if (Test-Path $proxyScript) {
    Write-Host "ContextFort installed successfully"
} else {
    throw "Installation failed"
}
```

#### Step 3: Deploy Chrome for Testing (Optional)

Pre-deploy Chrome for Testing to avoid 170MB download on first use:

```bash
# Included in enterprise package
/usr/local/contextfort/chrome/
```

---

### Method 2: Silent Installation Script

For organizations without MDM or for testing:

```bash
#!/bin/bash
# silent-install.sh - Enterprise silent installer

set -euo pipefail

INSTALL_DIR="/usr/local/contextfort"
COMPANY_NAME="Acme Corp"
IT_CONTACT="it-security@acme.com"

echo "Installing ContextFort for $COMPANY_NAME..."

# Check prerequisites
if ! command -v node &> /dev/null; then
    echo "Error: Node.js required. Contact $IT_CONTACT"
    exit 1
fi

# Create installation directory
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r ./plugin/* "$INSTALL_DIR/"
sudo chown -R root:wheel "$INSTALL_DIR"
sudo chmod -R 755 "$INSTALL_DIR"

# Set environment variables globally
sudo tee /etc/profile.d/contextfort.sh > /dev/null <<EOF
export CONTEXTFORT_PLUGIN_DIR="$INSTALL_DIR"
export CONTEXTFORT_ENTERPRISE_MODE="true"
export CONTEXTFORT_IT_CONTACT="$IT_CONTACT"
EOF

# Install native messaging proxy
export CONTEXTFORT_PLUGIN_DIR="$INSTALL_DIR"
"$INSTALL_DIR/bin/install-native-proxy.sh" --silent

echo "✅ ContextFort installed successfully"
echo "Users must restart Claude Desktop and Chrome"
```

**Deploy via SSH:**

```bash
# Deploy to all macOS workstations
ansible all -m copy -a "src=contextfort-plugin dest=/usr/local/contextfort"
ansible all -m shell -a "/usr/local/contextfort/bin/install-native-proxy.sh --silent"
```

---

### Method 3: Docker/Container Deployment

For cloud workstations or containerized environments:

```dockerfile
# Dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install ContextFort
COPY plugin /opt/contextfort
WORKDIR /opt/contextfort

# Install Chrome for Testing
RUN ./bin/launch-chrome.sh --download-only

# Configure environment
ENV CONTEXTFORT_PLUGIN_DIR=/opt/contextfort
ENV CONTEXTFORT_ENTERPRISE_MODE=true

# Install native messaging proxy
RUN ./bin/install-native-proxy.sh --silent

ENTRYPOINT ["/opt/contextfort/bin/native-messaging-proxy.js"]
```

---

## Enterprise Configuration

### Centralized Logging

**Send logs to SIEM:**

```bash
# Configure syslog forwarding
cat >> /etc/syslog.conf <<EOF
# ContextFort logs to Splunk
local7.* @@splunk.acme.com:514
EOF

# Update proxy to use syslog
export CONTEXTFORT_LOG_MODE=syslog
export CONTEXTFORT_SYSLOG_FACILITY=local7
```

**Azure Monitor Integration:**

```javascript
// In native-messaging-proxy.js
const { DefaultAzureCredential } = require("@azure/identity");
const { LogsIngestionClient } = require("@azure/monitor-ingestion");

// Send logs to Azure Log Analytics
async function logToAzure(message) {
  const credential = new DefaultAzureCredential();
  const client = new LogsIngestionClient(
    "https://your-endpoint.ingest.monitor.azure.com",
    credential
  );

  await client.upload(
    "dcr-ContextFortLogs",
    "ContextFort_CL",
    [{ message, timestamp: new Date() }]
  );
}
```

### Policy Enforcement

**Restrict Claude usage to ContextFort Chrome only:**

```bash
# Block regular Chrome from Claude connections
cat > /etc/hosts <<EOF
# Block direct Claude connections (force ContextFort)
127.0.0.1 claude.ai
::1 claude.ai
EOF

# Only allow through ContextFort proxy
# (Proxy whitelists claude.ai internally)
```

### Audit Configuration

```bash
# Full audit mode
export CONTEXTFORT_AUDIT_LEVEL=full          # Log everything
export CONTEXTFORT_SCREENSHOT_INTERVAL=5000   # Screenshot every 5s
export CONTEXTFORT_RETENTION_DAYS=90          # Keep logs 90 days

# Compliance mode
export CONTEXTFORT_COMPLIANCE_MODE=sox        # SOX compliance
export CONTEXTFORT_ENCRYPTION=true            # Encrypt logs at rest
export CONTEXTFORT_TAMPER_PROOF=true          # Immutable logs
```

---

## Security Features

### 1. **Ephemeral Sessions**
- All browsing data deleted after session
- Zero persistence (except auth template if configured)
- Fresh profile each time

### 2. **Complete Visibility**
- Every URL visited logged
- All form inputs captured
- Screenshots on interval
- Network requests tracked

### 3. **No Credential Leakage**
- Mock keychain (no macOS Keychain access)
- Basic password store (ephemeral only)
- No password import from system

### 4. **Isolated Environment**
- Separate Chrome for Testing binary
- No interaction with user's personal Chrome
- Controlled extension environment

### 5. **Tamper Detection**
- Proxy logs all intercepts
- Binary integrity checks
- Configuration drift alerts

---

## Monitoring & Alerts

### Key Metrics to Monitor

```bash
# Monitor ContextFort health
watch -n 5 'grep ERROR ~/.contextfort/logs/native-proxy.log | tail -10'

# Count daily sessions
grep "Chrome launched" ~/.contextfort/logs/*.log | wc -l

# Failed launches
grep "Failed to launch" ~/.contextfort/logs/*.log
```

### Alert Rules (Datadog Example)

```yaml
alerts:
  - name: ContextFort Proxy Failure
    query: "logs(\"contextfort\").error().rollup(count).last(5m) > 10"
    message: "ContextFort proxy failing, investigate immediately"
    priority: P1
    notify:
      - it-security@acme.com
      - slack-#security-alerts

  - name: Unusual Browser Activity
    query: "logs(\"contextfort\").filter(tabs > 10).last(1h)"
    message: "User opened 10+ tabs, possible data exfiltration"
    priority: P2
```

---

## User Onboarding

### For End Users

**Step 1:** IT installs ContextFort (no user action needed)

**Step 2:** User sees Chrome window open automatically when using Claude

**Step 3:** (Optional) One-time login to Claude-in-Chrome extension

**What Users See:**
- Chrome for Testing window (clearly labeled)
- ContextFort extension icon in toolbar
- Normal Claude workflow

**What Users DON'T See:**
- Background monitoring
- Log collection
- Session recording

### IT Communication Template

```
Subject: New Security Feature - ContextFort Browser Isolation

Team,

We've deployed ContextFort to enhance security when using Claude AI tools.

What this means:
✅ When Claude needs to use a browser, an isolated Chrome window opens
✅ All activity is monitored for compliance
✅ Zero data persists between sessions
✅ Your personal Chrome is unaffected

What you need to do:
1. Restart Claude Desktop app (if installed)
2. Login to Claude-in-Chrome extension (one-time)
3. Use Claude normally

The isolated browser window will close automatically when done.

Questions? Contact: it-security@acme.com

- IT Security Team
```

---

## Compliance & Certifications

### SOX Compliance
- Full audit trail of AI-assisted actions
- Immutable logs with timestamps
- User attribution for all sessions

### GDPR Compliance
- No PII stored (ephemeral sessions)
- Logs can be purged on data subject request
- Transparent to end users

### HIPAA Compliance
- PHI never persists locally
- Encrypted log transmission
- Access controls on audit logs

### ISO 27001
- Information security controls documented
- Risk assessment included
- Incident response procedures

---

## Troubleshooting

### Common Issues

**Issue:** Chrome doesn't launch
```bash
# Check proxy logs
tail -f ~/.contextfort/logs/native-proxy.log

# Verify installation
ls -la ~/agents-blocker/plugin/bin/native-messaging-proxy.js
node --version
```

**Issue:** Extension can't connect
```bash
# Verify native messaging config
cat ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json

# Should show ContextFort proxy path
```

**Issue:** Slow performance
```bash
# Check Chrome processes
ps aux | grep "Chrome for Testing" | wc -l

# Should be < 15 processes per session
```

---

## Uninstallation

### Remove from Single Workstation

```bash
/usr/local/contextfort/bin/uninstall-native-proxy.sh
sudo rm -rf /usr/local/contextfort
```

### Remove via MDM

```bash
# Jamf Pro
sudo jamf policy -event uninstall-contextfort

# Intune
Uninstall-Package -Name ContextFort
```

---

## Support

### Enterprise Support Tier

**24/7 Support:** enterprise-support@contextfort.ai
**Security Incidents:** security@contextfort.ai
**Deployment Help:** deployment@contextfort.ai

**SLA:**
- P1 (Critical): 1 hour response
- P2 (High): 4 hour response
- P3 (Medium): 1 business day

---

## Roadmap

### Upcoming Enterprise Features

- [ ] SAML/SSO integration
- [ ] Centralized policy management console
- [ ] Real-time session streaming
- [ ] Advanced DLP (Data Loss Prevention)
- [ ] Linux & Windows native support
- [ ] Kubernetes operator for cloud deployments

---

## License

Enterprise License includes:
- Unlimited users
- Priority support
- Custom integrations
- On-premises deployment option
- Annual security audits

Contact: sales@contextfort.ai
