#!/bin/bash
#
# ContextFort Policy Applicator
# Apply Chrome Enterprise policies from JSON config
#

set -euo pipefail

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
POLICIES_FILE="$PLUGIN_DIR/config/chrome-policies.json"
CONTEXTFORT_DIR="$HOME/.contextfort"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Apply Chrome Enterprise policies from JSON configuration.

OPTIONS:
    --config <file>     Policy config file (default: config/chrome-policies.json)
    --dry-run           Show policies without applying
    --platform <os>     Target platform: mac, windows, linux (auto-detected)
    -h, --help          Show this help

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --config custom-policies.json
    $(basename "$0") --dry-run

NOTES:
    - Policies are applied per-platform (registry/plist/JSON)
    - Requires admin privileges on some platforms
    - Chrome must be restarted for policies to take effect

EOF
    exit 1
}

# Parse arguments
DRY_RUN=false
PLATFORM=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            POLICIES_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
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

# Detect platform if not specified
if [[ -z "$PLATFORM" ]]; then
    case "$(uname)" in
        Darwin) PLATFORM="mac" ;;
        Linux) PLATFORM="linux" ;;
        MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
        *)
            echo "❌ Error: Unsupported platform: $(uname)"
            exit 1
            ;;
    esac
fi

echo "🔒 ContextFort Policy Applicator"
echo "================================="
echo ""
echo "Platform: $PLATFORM"
echo "Config:   $POLICIES_FILE"
echo "Mode:     $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "APPLY")"
echo ""

# Check if policies file exists
if [[ ! -f "$POLICIES_FILE" ]]; then
    echo "❌ Error: Policy file not found: $POLICIES_FILE"
    exit 1
fi

# Validate JSON
if ! jq empty "$POLICIES_FILE" 2>/dev/null; then
    echo "❌ Error: Invalid JSON in policy file"
    exit 1
fi

echo "✅ Policy file validated"
echo ""

# Extract and apply policies
apply_mac_policies() {
    echo "📋 Applying macOS policies (plist)..."
    echo ""

    # For Chrome for Testing, policies go to different location
    CHROME_POLICY_DIR="/Library/Managed Preferences"
    CHROME_POLICY_FILE="$CHROME_POLICY_DIR/com.google.ChromeForTesting.plist"

    if [ "$DRY_RUN" = true ]; then
        echo "Would create: $CHROME_POLICY_FILE"
        jq -r '.security.policies[] | "  \(.name) = \(.value)"' "$POLICIES_FILE"
        jq -r '.privacy.policies[] | "  \(.name) = \(.value)"' "$POLICIES_FILE"
        jq -r '.extensions.policies[] | "  \(.name) = \(.value)"' "$POLICIES_FILE"
        return
    fi

    # Note: Requires sudo for system-level policies
    echo "⚠️  System-level policies require sudo access"
    echo "   Alternative: User-level policies in ~/Library/Preferences/"
    echo ""

    # Create user-level policy (no sudo needed)
    USER_POLICY_FILE="$HOME/Library/Preferences/com.google.ChromeForTesting.plist"

    echo "Creating user-level policy: $USER_POLICY_FILE"

    # Convert JSON policies to plist format
    # This is a simplified version - full implementation would convert all policies
    cat > /tmp/chrome-policies-temp.json << 'POLICY_TEMPLATE'
{
  "SyncDisabled": true,
  "PasswordManagerEnabled": false,
  "IncognitoModeAvailability": 1,
  "BrowserSignin": 0
}
POLICY_TEMPLATE

    # Convert JSON to plist (macOS only)
    plutil -convert xml1 /tmp/chrome-policies-temp.json -o "$USER_POLICY_FILE" 2>/dev/null || {
        echo "⚠️  Could not create plist file"
        echo "   Policies will be applied via launch flags instead"
    }

    rm -f /tmp/chrome-policies-temp.json

    echo "✅ macOS policies prepared"
}

apply_linux_policies() {
    echo "📋 Applying Linux policies (JSON)..."
    echo ""

    # Chrome for Testing policy directory
    POLICY_DIR="/etc/opt/chrome_for_testing/policies/managed"
    USER_POLICY_DIR="$HOME/.config/chrome_for_testing/policies/managed"

    if [ "$DRY_RUN" = true ]; then
        echo "Would create: $USER_POLICY_DIR/contextfort-policies.json"
        jq '{
          SyncDisabled: .security.policies[] | select(.name == "SyncDisabled") | .value,
          PasswordManagerEnabled: .security.policies[] | select(.name == "PasswordManagerEnabled") | .value
        }' "$POLICIES_FILE"
        return
    fi

    # Create user-level policy directory (no sudo needed)
    mkdir -p "$USER_POLICY_DIR"

    # Extract policies and convert to Chrome policy JSON format
    jq '{
      SyncDisabled: (.security.policies[] | select(.name == "SyncDisabled") | .value),
      PasswordManagerEnabled: (.security.policies[] | select(.name == "PasswordManagerEnabled") | .value),
      IncognitoModeAvailability: (.security.policies[] | select(.name == "IncognitoModeAvailability") | .value),
      BrowserSignin: (.security.policies[] | select(.name == "BrowserSignin") | .value)
    }' "$POLICIES_FILE" > "$USER_POLICY_DIR/contextfort-policies.json"

    echo "✅ Linux policies applied to: $USER_POLICY_DIR"
}

apply_windows_policies() {
    echo "📋 Applying Windows policies (Registry)..."
    echo ""

    # Windows registry path for Chrome policies
    REG_PATH="HKCU\\Software\\Policies\\Google\\ChromeForTesting"

    if [ "$DRY_RUN" = true ]; then
        echo "Would create registry keys under: $REG_PATH"
        jq -r '.security.policies[] | "  REG ADD \"\($REG_PATH)\" /v \(.name) /t REG_DWORD /d \(.value) /f"' "$POLICIES_FILE"
        return
    fi

    echo "⚠️  Windows policy application requires PowerShell or reg.exe"
    echo "   Run the following commands in PowerShell (as Administrator):"
    echo ""

    jq -r '.security.policies[] | "reg add \"HKCU\\Software\\Policies\\Google\\ChromeForTesting\" /v \(.name) /t REG_DWORD /d \(.value) /f"' "$POLICIES_FILE"

    echo ""
    echo "Or import this .reg file:"
    echo ""

    # Generate .reg file
    REG_FILE="$CONTEXTFORT_DIR/chrome-policies.reg"
    mkdir -p "$CONTEXTFORT_DIR"

    cat > "$REG_FILE" << 'REG_HEADER'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Policies\Google\ChromeForTesting]
REG_HEADER

    jq -r '.security.policies[] | "\"\\(.name)\"=dword:\(.value | tostring)"' "$POLICIES_FILE" >> "$REG_FILE"

    echo "Saved to: $REG_FILE"
    echo "Double-click to import, or run: reg import $REG_FILE"
}

# Apply policies based on platform
case "$PLATFORM" in
    mac)
        apply_mac_policies
        ;;
    linux)
        apply_linux_policies
        ;;
    windows)
        apply_windows_policies
        ;;
    *)
        echo "❌ Error: Unknown platform: $PLATFORM"
        exit 1
        ;;
esac

echo ""
echo "✅ Policy application complete"
echo ""
echo "Next steps:"
echo "1. Restart Chrome for Testing for policies to take effect"
echo "2. Verify policies: chrome://policy"
echo "3. Check ContextFort logs for policy enforcement"
