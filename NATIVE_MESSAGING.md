# ContextFort Native Messaging Proxy

## Overview

This replaces the MCP-based approach with Native Messaging interception, working for **both Claude Desktop and Claude Code**.

## Architecture

### Before (MCP Only):
```
Claude Code → MCP Socket → PreToolUse Hook → Launch ContextFort Chrome
Claude Desktop → Native Messaging → Regular Chrome ❌ (no ContextFort)
```

### After (Native Messaging for Both):
```
Claude Code → Native Messaging → Proxy → Launch ContextFort Chrome ✅
Claude Desktop → Native Messaging → Proxy → Launch ContextFort Chrome ✅
```

## How It Works

1. **Intercept at Browser Level**
   - Claude-in-Chrome extension communicates via Native Messaging
   - We replace the native host binary with our proxy

2. **Proxy Responsibilities**
   - Check if ContextFort Chrome is running
   - If not, launch it automatically
   - Forward all messages to real native host
   - Return responses back to extension

3. **Transparent Operation**
   - Claude Desktop/Code work normally
   - ContextFort Chrome launches automatically
   - All browser sessions monitored
   - Full visibility and control

## Installation

### Step 1: Install the Proxy

```bash
cd /Users/ashwin/agents-blocker/plugin
./bin/install-native-proxy.sh
```

This will:
- Backup original native messaging config
- Replace it with ContextFort proxy
- Add environment variables
- Show instructions

### Step 2: Restart Applications

1. Close all Chrome windows
2. Restart Claude Desktop app
3. Restart Claude Code (if running)

### Step 3: Test

Use Claude-in-Chrome from either:
- Claude Desktop app (connectors)
- Claude Code (browser tools)

**Result:** ContextFort Chrome launches automatically! 🎉

## Files

- `bin/native-messaging-proxy.js` - Main proxy (Node.js)
- `bin/install-native-proxy.sh` - Installer
- `bin/uninstall-native-proxy.sh` - Uninstaller
- `~/.contextfort/logs/native-proxy.log` - Proxy logs

## Configuration

Native messaging config location:
```
~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json
```

Backup location:
```
~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json.contextfort-backup
```

## Uninstallation

To revert to original Claude behavior:

```bash
./bin/uninstall-native-proxy.sh
```

This restores the backup and removes ContextFort proxy.

## Debugging

### Check if proxy is running:
```bash
tail -f ~/.contextfort/logs/native-proxy.log
```

### Test native messaging manually:
```bash
echo '{"test": true}' | /Users/ashwin/agents-blocker/plugin/bin/native-messaging-proxy.js
```

### Check Chrome processes:
```bash
ps aux | grep -i "chrome for testing"
```

## Benefits Over MCP Approach

1. **Works for Both**
   - Claude Code ✅
   - Claude Desktop ✅

2. **Lower Level**
   - Intercepts at browser-extension boundary
   - More reliable than socket interception

3. **Simpler**
   - One proxy for everything
   - No hook system complexity

4. **Official Protocol**
   - Uses Chrome's Native Messaging API
   - Follows official standards

## Troubleshooting

### Chrome doesn't launch:
- Check logs: `~/.contextfort/logs/native-proxy.log`
- Verify plugin path: `echo $CONTEXTFORT_PLUGIN_DIR`
- Test launch script: `./bin/launch-chrome.sh`

### Extension can't connect:
- Restart Chrome completely
- Check native messaging config: `cat ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json`
- Verify proxy is executable: `ls -la bin/native-messaging-proxy.js`

### "Node.js not found":
- Install Node.js: https://nodejs.org
- Verify: `node --version`

## Security

- Proxy logs all messages to `~/.contextfort/logs/native-proxy.log`
- Original config backed up automatically
- Easy to uninstall and revert
- No modification of Claude apps themselves
