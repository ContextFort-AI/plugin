#!/bin/bash
#
# ContextFort macOS .pkg Installer Builder
# Creates deployable .pkg for Jamf/Intune/Kandji
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PKG_ROOT="$BUILD_DIR/root"
PKG_SCRIPTS="$BUILD_DIR/scripts"
OUTPUT_PKG="$BUILD_DIR/ContextFort-$(cat "$PLUGIN_DIR/VERSION" 2>/dev/null || echo "1.0.0").pkg"

echo "📦 ContextFort macOS Package Builder"
echo "====================================="
echo ""

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$PKG_ROOT" "$PKG_SCRIPTS"

echo "✅ Build directory created: $BUILD_DIR"
echo ""

# 1. Create package root structure
echo "📁 Creating package structure..."
mkdir -p "$PKG_ROOT/usr/local/contextfort"
mkdir -p "$PKG_ROOT/Library/Application Support/Google/Chrome/NativeMessagingHosts"

# Copy plugin files
cp -r "$PLUGIN_DIR/bin" "$PKG_ROOT/usr/local/contextfort/"
cp -r "$PLUGIN_DIR/extension" "$PKG_ROOT/usr/local/contextfort/"
cp -r "$PLUGIN_DIR/config" "$PKG_ROOT/usr/local/contextfort/"

# Copy native messaging host config (template)
cat > "$PKG_ROOT/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json" << 'EOF'
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host (ContextFort Proxy)",
  "path": "/usr/local/contextfort/bin/native-messaging-proxy.js",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
  ]
}
EOF

echo "✅ Package root populated"
echo ""

# 2. Create postinstall script
echo "📝 Creating postinstall script..."
cat > "$PKG_SCRIPTS/postinstall" << 'POSTINSTALL'
#!/bin/bash
#
# ContextFort Post-Install Script
#

# Get the user who invoked the installer (even with sudo)
REAL_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo ~$REAL_USER)

echo "Installing ContextFort for user: $REAL_USER"

# Create ContextFort directory
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.contextfort/logs"

# Make scripts executable
chmod +x /usr/local/contextfort/bin/*.sh
chmod +x /usr/local/contextfort/bin/*.js

# Create symlinks for easy access
ln -sf /usr/local/contextfort/bin/launch-chrome.sh /usr/local/bin/contextfort-chrome
ln -sf /usr/local/contextfort/bin/kill-session.sh /usr/local/bin/contextfort-kill

# Download Chrome for Testing (if not present)
if [[ ! -d "/usr/local/contextfort/chrome" ]]; then
    echo "Downloading Chrome for Testing..."
    sudo -u "$REAL_USER" /usr/local/contextfort/bin/launch-chrome.sh --download-only 2>&1 || true
fi

echo "ContextFort installed successfully"
echo "Run: contextfort-chrome to launch"

exit 0
POSTINSTALL

chmod +x "$PKG_SCRIPTS/postinstall"
echo "✅ Postinstall script created"
echo ""

# 3. Create preinstall script (backup existing config)
cat > "$PKG_SCRIPTS/preinstall" << 'PREINSTALL'
#!/bin/bash
#
# ContextFort Pre-Install Script
#

REAL_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo ~$REAL_USER)
NATIVE_HOST_CONFIG="$USER_HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json"

# Backup existing native messaging config
if [[ -f "$NATIVE_HOST_CONFIG" ]]; then
    cp "$NATIVE_HOST_CONFIG" "$NATIVE_HOST_CONFIG.backup.$(date +%s)"
    echo "Backed up existing native messaging config"
fi

exit 0
PREINSTALL

chmod +x "$PKG_SCRIPTS/preinstall"

echo "✅ Preinstall script created"
echo ""

# 4. Build the package
echo "🔨 Building .pkg..."
echo ""

pkgbuild \
  --root "$PKG_ROOT" \
  --scripts "$PKG_SCRIPTS" \
  --identifier "com.contextfort.agent" \
  --version "$(cat "$PLUGIN_DIR/VERSION" 2>/dev/null || echo "1.0.0")" \
  --install-location "/" \
  "$OUTPUT_PKG"

if [[ $? -eq 0 ]]; then
    echo ""
    echo "✅ Package built successfully!"
    echo ""
    echo "Output: $OUTPUT_PKG"
    echo "Size: $(du -h "$OUTPUT_PKG" | cut -f1)"
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo ""
    echo "1. SIGN THE PACKAGE (Required for Jamf/Intune):"
    echo "   productsign --sign \"Developer ID Installer: Your Name\" \\"
    echo "     \"$OUTPUT_PKG\" \\"
    echo "     \"$BUILD_DIR/ContextFort-signed.pkg\""
    echo ""
    echo "2. NOTARIZE (Required for macOS 10.15+):"
    echo "   xcrun notarytool submit \\"
    echo "     \"$BUILD_DIR/ContextFort-signed.pkg\" \\"
    echo "     --apple-id \"your@email.com\" \\"
    echo "     --team-id \"TEAM_ID\" \\"
    echo "     --password \"@keychain:AC_PASSWORD\""
    echo ""
    echo "3. STAPLE NOTARIZATION:"
    echo "   xcrun stapler staple \"$BUILD_DIR/ContextFort-signed.pkg\""
    echo ""
    echo "4. UPLOAD TO JAMF:"
    echo "   - Open Jamf Pro"
    echo "   - Settings → Computer Management → Packages"
    echo "   - Upload ContextFort-signed.pkg"
    echo "   - Create policy to deploy"
    echo ""
    echo "5. TEST INSTALLATION:"
    echo "   sudo installer -pkg \"$OUTPUT_PKG\" -target /"
    echo ""
else
    echo "❌ Package build failed"
    exit 1
fi
