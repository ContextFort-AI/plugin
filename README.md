# ContextFort Plugin

Enterprise browser isolation for Claude Desktop and Claude Code.

## Quick Start

```bash
# Install native messaging proxy
./bin/install-native-proxy.sh

# Restart Chrome and Claude Desktop
# ContextFort Chrome launches automatically when using Claude!
```

## What It Does

ContextFort intercepts Claude-in-Chrome connections and launches isolated browser sessions with full monitoring:

- ✅ **Ephemeral sessions** - All data deleted after use
- ✅ **Complete visibility** - Every action logged and monitored
- ✅ **No credential leakage** - Mock keychain, isolated environment
- ✅ **Works everywhere** - Claude Desktop + Claude Code

## Architecture

```
Claude Desktop/Code
        ↓
Native Messaging Proxy (ContextFort)
        ↓
Isolated Chrome for Testing
        ↓
ContextFort Extension (monitoring)
```

## Installation

### Prerequisites
- Node.js (for proxy)
- macOS or Linux
- Claude Desktop app or Claude Code

### Install

```bash
cd /path/to/plugin
./bin/install-native-proxy.sh
```

### Uninstall

```bash
./bin/uninstall-native-proxy.sh
```

## Enterprise Deployment

See [ENTERPRISE_DEPLOYMENT.md](ENTERPRISE_DEPLOYMENT.md) for:
- MDM deployment (Jamf/Intune)
- Centralized logging (SIEM)
- Policy enforcement
- Compliance (SOX/GDPR/HIPAA)

## Documentation

- [NATIVE_MESSAGING.md](NATIVE_MESSAGING.md) - Technical architecture
- [ENTERPRISE_DEPLOYMENT.md](ENTERPRISE_DEPLOYMENT.md) - Fortune 500 deployment
- Logs: `~/.contextfort/logs/`

## Files

```
plugin/
├── bin/
│   ├── native-messaging-proxy.js     # Main proxy
│   ├── install-native-proxy.sh       # Installer
│   ├── uninstall-native-proxy.sh     # Uninstaller
│   ├── launch-chrome.sh              # Chrome launcher
│   └── setup-auth.sh                 # Auth template setup
├── extension/                        # ContextFort monitoring extension
├── chrome/                           # Chrome for Testing (auto-downloaded)
└── *.md                              # Documentation
```

## How It Works

1. User triggers Claude browser action
2. Native messaging proxy intercepts
3. Proxy launches ContextFort Chrome (if not running)
4. Extension monitors all activity
5. Session ends → everything deleted

## Security

- No data persists between sessions
- All logs encrypted and auditable
- No system keychain access
- Isolated from personal Chrome

## Support

- GitHub Issues: https://github.com/ContextFort-AI/plugin/issues
- Enterprise: enterprise@contextfort.ai

## License

MIT
