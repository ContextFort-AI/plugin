#!/bin/bash
#
# ContextFort Plugin Installer
#
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🛡️  ContextFort Plugin Installer"
echo "================================"
echo ""

# Download Chrome for Testing
echo "📦 Downloading Chrome for Testing..."

CHROME_DIR="$PLUGIN_ROOT/chrome"

if [[ -d "$CHROME_DIR" ]] && [[ -n "$(ls -A "$CHROME_DIR" 2>/dev/null)" ]]; then
    echo "✅ Chrome for Testing already installed"
else
    mkdir -p "$CHROME_DIR"

    if [[ "$(uname)" == "Darwin" ]]; then
        DOWNLOAD_URL="https://storage.googleapis.com/chrome-for-testing-public/143.0.7499.192/mac-x64/chrome-mac-x64.zip"
    elif [[ "$(uname)" == "Linux" ]]; then
        DOWNLOAD_URL="https://storage.googleapis.com/chrome-for-testing-public/143.0.7499.192/linux64/chrome-linux64.zip"
    else
        echo "❌ Error: Unsupported platform"
        exit 1
    fi

    echo "   Source: $DOWNLOAD_URL"
    echo "   Size: ~170MB"
    echo ""

    if curl -# -L -o "$CHROME_DIR/chrome.zip" "$DOWNLOAD_URL"; then
        echo "✅ Download complete"
        echo "📦 Extracting..."
        unzip -q "$CHROME_DIR/chrome.zip" -d "$CHROME_DIR"
        rm "$CHROME_DIR/chrome.zip"
        echo "✅ Chrome for Testing installed"
    else
        echo "❌ Error: Failed to download Chrome for Testing"
        exit 1
    fi
fi

echo ""
echo "🎉 Installation Complete!"
echo ""
echo "Chrome for Testing has been downloaded."
echo ""
echo "To install in Claude Code:"
echo "  /plugin install https://github.com/ContextFort-AI/plugin"
echo ""
echo "Note: This script is optional. Chrome will auto-download on first use if not present."
echo ""
