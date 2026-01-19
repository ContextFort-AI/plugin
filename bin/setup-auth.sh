#!/bin/bash
#
# ContextFort Authentication Setup
# One-time setup: Login to Claude and save authenticated profile as template
#

set -euo pipefail

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TEMPLATE_DIR="$HOME/.contextfort/profile-template"
SETUP_PROFILE="/tmp/contextfort-setup-$$"

echo "🛡️  ContextFort Authentication Setup"
echo "===================================="
echo ""
echo "This will:"
echo "1. Launch Chrome for Testing"
echo "2. Load Claude-in-Chrome extension"
echo "3. Wait for you to login to Claude"
echo "4. Save your authenticated profile as a template"
echo ""
echo "After this, all future sessions will start with Claude already logged in!"
echo ""
read -p "Press Enter to continue..."

# Check if Chrome binary exists
if [[ "$(uname)" == "Darwin" ]]; then
    CHROME_BIN="$PLUGIN_DIR/chrome/chrome-mac-x64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
elif [[ "$(uname)" == "Linux" ]]; then
    CHROME_BIN="$PLUGIN_DIR/chrome/chrome-linux64/chrome"
else
    echo "❌ Error: Unsupported platform"
    exit 1
fi

if [[ ! -x "$CHROME_BIN" ]]; then
    echo "❌ Error: Chrome for Testing not found"
    echo "   Please run the plugin installer first"
    exit 1
fi

# Prepare setup profile
mkdir -p "$SETUP_PROFILE"
echo "$$" > "$SETUP_PROFILE/contextfort-session-id.txt"

# Copy ContextFort extension
CONTEXTFORT_EXT_DIR="$PLUGIN_DIR/extension"
if [[ -d "$CONTEXTFORT_EXT_DIR" ]]; then
    cp -r "$CONTEXTFORT_EXT_DIR" "$SETUP_PROFILE/ContextFortExtension"
    echo "✅ ContextFort extension prepared"
else
    echo "❌ ERROR: ContextFort extension not found"
    exit 1
fi

# Copy Claude-in-Chrome extension
CLAUDE_EXT_SOURCE="/Users/ashwin/Library/Application Support/Google/Chrome/Profile 1/Extensions/fcoeoabgfenejglbffodgkkbkcdhcgfn/1.0.40_0"
if [[ -d "$CLAUDE_EXT_SOURCE" ]]; then
    cp -r "$CLAUDE_EXT_SOURCE" "$SETUP_PROFILE/ClaudeInChrome"
    echo "✅ Claude-in-Chrome extension prepared"
    EXTENSIONS_TO_LOAD="$SETUP_PROFILE/ContextFortExtension,$SETUP_PROFILE/ClaudeInChrome"
else
    echo "⚠️  Warning: Claude-in-Chrome not found, using ContextFort only"
    EXTENSIONS_TO_LOAD="$SETUP_PROFILE/ContextFortExtension"
fi

echo ""
echo "🚀 Launching Chrome for Testing..."
echo ""
echo "INSTRUCTIONS:"
echo "1. Click the Claude extension icon in the toolbar"
echo "2. Login to your Claude account"
echo "3. Wait for login to complete"
echo "4. Come back to this terminal and press Enter"
echo ""

# Launch Chrome
"$CHROME_BIN" \
    --user-data-dir="$SETUP_PROFILE" \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-networking \
    --disable-sync \
    --use-mock-keychain \
    --password-store=basic \
    --window-size=1920,1080 \
    --load-extension="$EXTENSIONS_TO_LOAD" \
    --disable-extensions-except="$EXTENSIONS_TO_LOAD" \
    "https://claude.ai/login" \
    > /dev/null 2>&1 &

CHROME_PID=$!
echo "Chrome launched (PID: $CHROME_PID)"
echo ""

# Wait for user to complete login
read -p "Press Enter AFTER you've logged into Claude..."

# Check if Chrome is still running
if ! kill -0 "$CHROME_PID" 2>/dev/null; then
    echo "❌ Error: Chrome closed unexpectedly"
    rm -rf "$SETUP_PROFILE"
    exit 1
fi

# Kill Chrome gracefully
echo ""
echo "Saving authenticated profile template..."
kill "$CHROME_PID" 2>/dev/null || true
sleep 2

# Save profile as template
if [[ -d "$TEMPLATE_DIR" ]]; then
    echo "Removing old template..."
    rm -rf "$TEMPLATE_DIR"
fi

mkdir -p "$(dirname "$TEMPLATE_DIR")"
cp -r "$SETUP_PROFILE" "$TEMPLATE_DIR"

# Cleanup setup profile
rm -rf "$SETUP_PROFILE"

# Get template size
TEMPLATE_SIZE=$(du -sh "$TEMPLATE_DIR" | awk '{print $1}')

echo ""
echo "✅ Authentication template saved!"
echo "   Location: $TEMPLATE_DIR"
echo "   Size: $TEMPLATE_SIZE"
echo ""
echo "🎉 Setup complete!"
echo ""
echo "All future Chrome sessions will start with Claude already logged in."
echo "No need to login again unless you want to change accounts."
echo ""
