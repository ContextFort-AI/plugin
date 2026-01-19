# ContextFort Plugin

Enterprise browser isolation for Claude Code.

## Installation

```bash
/plugin install https://github.com/ContextFort-AI/plugin
```

Chrome for Testing (~170MB) will automatically download on first use.

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
