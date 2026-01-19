# ContextFort Plugin

Enterprise browser isolation for Claude Code.

## Installation

### Quick Install (Recommended)

```bash
/plugin install https://github.com/ContextFort-AI/plugin
```

Chrome for Testing (~170MB) will automatically download on first use.

### Pre-download Chrome (Optional)

To avoid the download delay on first use, you can pre-download Chrome:

```bash
git clone https://github.com/ContextFort-AI/plugin
cd plugin
./INSTALL.sh
```

Then install locally:

```bash
/plugin install /path/to/plugin
```

## Enterprise Deployment

For managed enterprise deployments, add the plugin repository to your allowlist:

```json
{
  "plugins": {
    "strictKnownMarketplaces": [
      "https://github.com/ContextFort-AI/plugin"
    ]
  }
}
```

Deploy via MDM (Jamf/Intune) to your organization's Claude Code installations.

## How It Works

ContextFort intercepts browser tool calls and launches an isolated Chrome instance with:

- Ephemeral profiles (auto-deleted after use)
- Extension monitoring and event capture
- Session tracking via dashboard
- Zero persistent data between sessions

## Requirements

- Claude Code
- macOS or Linux
- Internet connection (for Chrome download)

## License

MIT
