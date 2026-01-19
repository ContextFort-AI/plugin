#!/bin/bash
#
# ContextFort Native Messaging Proxy Uninstaller
# Restores original Claude native messaging configuration
#

set -euo pipefail

NATIVE_HOST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
CONFIG_FILE="$NATIVE_HOST_DIR/com.anthropic.claude_browser_extension.json"
BACKUP_FILE="$CONFIG_FILE.contextfort-backup"

echo "🛡️  ContextFort Native Messaging Proxy Uninstaller"
echo "==================================================="
echo ""

# Check if backup exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "❌ Error: No backup found at $BACKUP_FILE"
    echo "   Cannot restore original configuration"
    exit 1
fi

echo "✅ Backup found: $BACKUP_FILE"
echo ""

# Show current config
echo "Current config:"
cat "$CONFIG_FILE"
echo ""

# Restore backup
echo "📦 Restoring original configuration..."
cp "$BACKUP_FILE" "$CONFIG_FILE"

echo "✅ Original configuration restored"
echo ""
echo "Restored config:"
cat "$CONFIG_FILE"
echo ""

echo "🎉 Uninstallation Complete!"
echo ""
echo "⚠️  IMPORTANT: Restart Chrome and Claude Desktop app for changes to take effect"
echo ""
echo "The backup file has been kept at: $BACKUP_FILE"
echo "You can delete it manually if you want:"
echo "  rm \"$BACKUP_FILE\""
echo ""
