#!/bin/bash
#
# ContextFort Plugin Installer
# Installs the plugin to Claude Code plugins directory
#

set -euo pipefail

PLUGIN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/contextfort" && pwd)"
PLUGIN_DEST="$HOME/.claude/plugins/contextfort"
CONTEXTFORT_DIR="$HOME/.contextfort"

echo "🛡️  ContextFort Plugin Installer"
echo "================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check Claude Code
if ! command -v claude &> /dev/null; then
    echo "❌ Error: Claude Code not found"
    echo "   Please install Claude Code first"
    exit 1
fi
echo "✅ Claude Code installed"

# Check Chrome
if [[ -d "/Applications/Google Chrome.app" ]] || command -v google-chrome &> /dev/null || command -v chromium-browser &> /dev/null; then
    echo "✅ Chrome installed"
else
    echo "❌ Error: Chrome not found"
    echo "   Please install Google Chrome"
    exit 1
fi

echo ""

# Check if plugin already installed
if [[ -d "$PLUGIN_DEST" ]]; then
    echo "⚠️  ContextFort already installed at: $PLUGIN_DEST"
    read -p "   Overwrite? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi

    echo "Removing existing installation..."
    rm -rf "$PLUGIN_DEST"
fi

# Install plugin
echo "Installing ContextFort plugin..."

# Create plugins directory if it doesn't exist
mkdir -p "$HOME/.claude/plugins"

# Copy plugin files
cp -r "$PLUGIN_SRC" "$PLUGIN_DEST"

echo "✅ Plugin installed to: $PLUGIN_DEST"

# Make scripts executable
chmod +x "$PLUGIN_DEST/hooks"/*.sh
chmod +x "$PLUGIN_DEST/bin"/*.sh

echo "✅ Scripts made executable"

# Create ContextFort directory structure
echo "Setting up ContextFort directories..."
mkdir -p "$CONTEXTFORT_DIR"/{sessions,logs}

echo "✅ Created $CONTEXTFORT_DIR"

# Create initial config if it doesn't exist
CONFIG_FILE="$PLUGIN_DEST/config/settings.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<EOF
{
  "dashboardUrl": "http://localhost:8080",
  "maxSessionDuration": 3600,
  "screenshotInterval": 30,
  "retentionDays": 90,
  "autoCleanup": true,
  "logLevel": "info"
}
EOF
    echo "✅ Created default configuration"
fi

echo ""
echo "🎉 Installation Complete!"
echo ""
echo "Next Steps:"
echo "-----------"
echo "1. Start the dashboard:"
echo "   cd $(dirname "$PLUGIN_SRC")/../contextfort-dashboard"
echo "   npm install"
echo "   npm run dev"
echo ""
echo "2. Test the installation:"
echo "   claude"
echo "   # Then type:"
echo "   /contextfort status"
echo ""
echo "3. Try it out:"
echo "   # Just use Claude normally, ContextFort works automatically!"
echo "   claude \"check my github notifications\""
echo ""
echo "Commands:"
echo "  /contextfort status    - Check status"
echo "  /contextfort dashboard - Open dashboard"
echo "  /contextfort cleanup   - Manual cleanup"
echo ""
echo "Documentation: $(dirname "$PLUGIN_SRC")/contextfort/README.md"
echo ""
