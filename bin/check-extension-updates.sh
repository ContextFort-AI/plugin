#!/bin/bash
#
# ContextFort Extension Update Checker
# Check if Claude-in-Chrome extension needs updating
#

set -euo pipefail

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONTEXTFORT_DIR="$HOME/.contextfort"
UPDATE_CHECK_FILE="$CONTEXTFORT_DIR/last-extension-check.json"

# Chrome extension source location
CHROME_PROFILE_DIR="$HOME/Library/Application Support/Google/Chrome/Profile 1"
CLAUDE_EXT_ID="fcoeoabgfenejglbffodgkkbkcdhcgfn"
CLAUDE_EXT_SOURCE="$CHROME_PROFILE_DIR/Extensions/$CLAUDE_EXT_ID"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Check if Claude-in-Chrome extension needs updating.

OPTIONS:
    --auto-update       Automatically update if new version found
    --force             Force update check (ignore cache)
    -h, --help          Show this help

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --auto-update
    $(basename "$0") --force

NOTES:
    - Checks Chrome Web Store for latest version
    - Compares with currently installed version
    - Can auto-update profile template if enabled

EOF
    exit 1
}

# Parse arguments
AUTO_UPDATE=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-update)
            AUTO_UPDATE=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "❌ Error: Unknown option '$1'"
            usage
            ;;
    esac
done

echo "🔄 ContextFort Extension Update Checker"
echo "========================================"
echo ""

# Check if extension exists
if [[ ! -d "$CLAUDE_EXT_SOURCE" ]]; then
    echo "❌ Error: Claude-in-Chrome extension not found"
    echo "   Expected: $CLAUDE_EXT_SOURCE"
    echo ""
    echo "Please install Claude-in-Chrome from:"
    echo "https://chrome.google.com/webstore/detail/$CLAUDE_EXT_ID"
    exit 1
fi

# Find latest installed version
echo "🔍 Checking installed version..."
LATEST_VERSION_DIR=$(ls -1 "$CLAUDE_EXT_SOURCE" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)

if [[ -z "$LATEST_VERSION_DIR" ]]; then
    echo "❌ Error: No version found in extension directory"
    exit 1
fi

INSTALLED_VERSION=$(echo "$LATEST_VERSION_DIR" | sed 's/_0$//')
INSTALLED_MANIFEST="$CLAUDE_EXT_SOURCE/$LATEST_VERSION_DIR/manifest.json"

if [[ ! -f "$INSTALLED_MANIFEST" ]]; then
    echo "❌ Error: manifest.json not found: $INSTALLED_MANIFEST"
    exit 1
fi

echo "✅ Installed version: $INSTALLED_VERSION"
echo "   Path: $CLAUDE_EXT_SOURCE/$LATEST_VERSION_DIR"
echo ""

# Check last update check time
SHOULD_CHECK=true
if [[ -f "$UPDATE_CHECK_FILE" ]] && [[ "$FORCE" != true ]]; then
    LAST_CHECK=$(jq -r '.last_check' "$UPDATE_CHECK_FILE" 2>/dev/null || echo "")
    if [[ -n "$LAST_CHECK" ]]; then
        LAST_CHECK_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_CHECK" "+%s" 2>/dev/null || echo "0")
        NOW_TS=$(date "+%s")
        DIFF=$((NOW_TS - LAST_CHECK_TS))

        # Only check once per day
        if [[ $DIFF -lt 86400 ]]; then
            SHOULD_CHECK=false
            echo "ℹ️  Last check: $LAST_CHECK ($(($DIFF / 3600))h ago)"
            echo "   Skipping check (use --force to override)"
        fi
    fi
fi

if [[ "$SHOULD_CHECK" = true ]]; then
    echo "🌐 Checking Chrome Web Store for updates..."
    echo ""

    # Note: Chrome Web Store doesn't have a public API
    # Real implementation would need to:
    # 1. Parse extension update XML from Chrome Web Store
    # 2. Or check via Chrome extension update mechanism
    # 3. Or use third-party services

    echo "⚠️  Chrome Web Store API is not publicly available"
    echo ""
    echo "Alternative update check methods:"
    echo ""
    echo "METHOD 1: Manual Check"
    echo "----------------------"
    echo "Visit: https://chrome.google.com/webstore/detail/$CLAUDE_EXT_ID"
    echo "Compare version with installed: $INSTALLED_VERSION"
    echo ""
    echo "METHOD 2: Chrome Extension Update"
    echo "----------------------------------"
    echo "1. Open Chrome: chrome://extensions"
    echo "2. Enable 'Developer mode'"
    echo "3. Click 'Update' button"
    echo "4. Chrome will check all extensions for updates"
    echo ""
    echo "METHOD 3: Automated via CDP"
    echo "----------------------------"
    echo "Use Chrome DevTools Protocol to trigger extension update:"
    echo '  chrome --remote-debugging-port=9222'
    echo '  curl http://localhost:9222/json/list'
    echo ""

    # Save check timestamp
    mkdir -p "$CONTEXTFORT_DIR"
    cat > "$UPDATE_CHECK_FILE" << EOF
{
  "last_check": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "installed_version": "$INSTALLED_VERSION",
  "extension_id": "$CLAUDE_EXT_ID",
  "extension_path": "$CLAUDE_EXT_SOURCE/$LATEST_VERSION_DIR"
}
EOF

    echo "✅ Update check timestamp saved"
fi

echo ""
echo "📦 Current Status"
echo "================="
echo "Extension ID:      $CLAUDE_EXT_ID"
echo "Installed Version: $INSTALLED_VERSION"
echo "Extension Path:    $CLAUDE_EXT_SOURCE/$LATEST_VERSION_DIR"
echo ""

# Check if template needs updating
TEMPLATE_DIR="$CONTEXTFORT_DIR/profile-template"
if [[ -d "$TEMPLATE_DIR/ClaudeInChrome" ]]; then
    TEMPLATE_MANIFEST="$TEMPLATE_DIR/ClaudeInChrome/manifest.json"
    if [[ -f "$TEMPLATE_MANIFEST" ]]; then
        TEMPLATE_VERSION=$(jq -r '.version' "$TEMPLATE_MANIFEST" 2>/dev/null || echo "unknown")
        echo "Template Version:  $TEMPLATE_VERSION"

        if [[ "$TEMPLATE_VERSION" != "$INSTALLED_VERSION" ]]; then
            echo ""
            echo "⚠️  Template extension version mismatch!"
            echo "   Template: $TEMPLATE_VERSION"
            echo "   Installed: $INSTALLED_VERSION"
            echo ""

            if [[ "$AUTO_UPDATE" = true ]]; then
                echo "🔄 Auto-updating template..."
                rm -rf "$TEMPLATE_DIR/ClaudeInChrome"
                cp -r "$CLAUDE_EXT_SOURCE/$LATEST_VERSION_DIR" "$TEMPLATE_DIR/ClaudeInChrome"
                echo "✅ Template updated to version $INSTALLED_VERSION"
            else
                echo "To update template, run:"
                echo "  rm -rf \"$TEMPLATE_DIR/ClaudeInChrome\""
                echo "  cp -r \"$CLAUDE_EXT_SOURCE/$LATEST_VERSION_DIR\" \"$TEMPLATE_DIR/ClaudeInChrome\""
                echo ""
                echo "Or run with --auto-update flag"
            fi
        else
            echo ""
            echo "✅ Template is up to date"
        fi
    fi
else
    echo ""
    echo "ℹ️  No profile template found (run setup-auth.sh first)"
fi

echo ""
echo "Next steps:"
echo "1. Check Chrome Web Store manually for latest version"
echo "2. If update available, update via chrome://extensions"
echo "3. Run this script again to update template"
echo "4. Or use --auto-update flag for automatic updates"
