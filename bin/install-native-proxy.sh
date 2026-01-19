#!/bin/bash
#
# ContextFort Native Messaging Proxy Installer
# Installs proxy for both Claude Desktop and Claude Code
#

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NATIVE_HOST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
CONFIG_FILE="$NATIVE_HOST_DIR/com.anthropic.claude_browser_extension.json"
BACKUP_FILE="$CONFIG_FILE.contextfort-backup"
PROXY_SCRIPT="$PLUGIN_DIR/bin/native-messaging-proxy.js"

echo "🛡️  ContextFort Native Messaging Proxy Installer"
echo "================================================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed"
    echo "   Please install Node.js from https://nodejs.org"
    exit 1
fi

echo "✅ Node.js found: $(node --version)"

# Check if proxy script exists
if [[ ! -f "$PROXY_SCRIPT" ]]; then
    echo "❌ Error: Proxy script not found at $PROXY_SCRIPT"
    exit 1
fi

echo "✅ Proxy script found"

# Check if native messaging config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Error: Claude native messaging config not found"
    echo "   Expected: $CONFIG_FILE"
    echo ""
    echo "   Make sure Claude Desktop app is installed and you've used Claude-in-Chrome at least once"
    exit 1
fi

echo "✅ Native messaging config found"

# Backup original config if not already backed up
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo ""
    echo "📦 Backing up original config..."
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "✅ Backup saved: $BACKUP_FILE"
else
    echo ""
    echo "ℹ️  Backup already exists: $BACKUP_FILE"
fi

# Read original config
ORIGINAL_JSON=$(cat "$CONFIG_FILE")
echo ""
echo "Original config:"
echo "$ORIGINAL_JSON"
echo ""

# Create new config pointing to proxy
cat > "$CONFIG_FILE" <<EOF
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host (ContextFort Proxy)",
  "path": "$PROXY_SCRIPT",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://dihbgbndebgnbjfmelmegjepbnkhlgni/",
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/",
    "chrome-extension://dngcpimnedloihjnnfngkgjoidhnaolf/"
  ]
}
EOF

echo "✅ Native messaging config updated"
echo ""
echo "New config:"
cat "$CONFIG_FILE"
echo ""

# Set environment variable for proxy
cat >> "$HOME/.bashrc" <<'EOF' || true

# ContextFort plugin directory (for native messaging proxy)
export CONTEXTFORT_PLUGIN_DIR="$HOME/agents-blocker/plugin"
EOF

cat >> "$HOME/.zshrc" <<'EOF' || true

# ContextFort plugin directory (for native messaging proxy)
export CONTEXTFORT_PLUGIN_DIR="$HOME/agents-blocker/plugin"
EOF

echo "✅ Environment variable added to shell configs"
echo ""
echo "🎉 Installation Complete!"
echo ""
echo "What happens now:"
echo "1. Claude Desktop app → Uses ContextFort Chrome automatically"
echo "2. Claude Code → Uses ContextFort Chrome automatically"
echo "3. All browser sessions monitored by ContextFort extension"
echo ""
echo "⚠️  IMPORTANT: Restart Chrome and Claude Desktop app for changes to take effect"
echo ""
echo "To test:"
echo "  1. Close all Chrome windows"
echo "  2. Restart Claude Desktop app"
echo "  3. Use Claude-in-Chrome connector"
echo "  4. ContextFort Chrome should launch automatically!"
echo ""
echo "To uninstall:"
echo "  Run: $PLUGIN_DIR/bin/uninstall-native-proxy.sh"
echo ""
