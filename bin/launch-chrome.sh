#!/bin/bash
#
# ContextFort Chrome Launcher
# Launches ephemeral Chrome instance with monitoring
#

set -euo pipefail

# Configuration
CONTEXTFORT_DIR="$HOME/.contextfort"
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/contextfort}"
PLUGIN_DATA_DIR="$PLUGIN_DIR/data"
SESSION_ID=$(date +%s)
PROFILE_DIR="/tmp/contextfort-${SESSION_ID}"
LOG_FILE="$PLUGIN_DATA_DIR/logs/launch.log"
SESSION_FILE="$PLUGIN_DATA_DIR/sessions/${SESSION_ID}.json"

# Ensure directories exist early (before any logging)
mkdir -p "$PLUGIN_DATA_DIR/"{sessions,logs,events}
mkdir -p "$CONTEXTFORT_DIR/logs"

# Logging function (defined early to avoid macOS log command conflict)
write_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Use bundled Chrome for Testing (enterprise self-contained)
# No system dependencies, no fallbacks
if [[ "$(uname)" == "Darwin" ]]; then
    CHROME_BIN="$PLUGIN_DIR/chrome/chrome-mac-x64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
    DOWNLOAD_URL="https://storage.googleapis.com/chrome-for-testing-public/143.0.7499.192/mac-x64/chrome-mac-x64.zip"
elif [[ "$(uname)" == "Linux" ]]; then
    CHROME_BIN="$PLUGIN_DIR/chrome/chrome-linux64/chrome"
    DOWNLOAD_URL="https://storage.googleapis.com/chrome-for-testing-public/143.0.7499.192/linux64/chrome-linux64.zip"
else
    write_log "❌ Error: Unsupported platform"
    exit 1
fi

# Auto-download Chrome if not present
if [[ ! -x "$CHROME_BIN" ]]; then
    write_log "📦 Chrome for Testing not found, downloading..."
    write_log "   This is a one-time download (~170MB)"

    CHROME_DIR="$PLUGIN_DIR/chrome"
    mkdir -p "$CHROME_DIR"

    write_log "   Source: $DOWNLOAD_URL"

    if curl -# -L -o "$CHROME_DIR/chrome.zip" "$DOWNLOAD_URL"; then
        write_log "✅ Download complete, extracting..."
        unzip -q "$CHROME_DIR/chrome.zip" -d "$CHROME_DIR"
        rm "$CHROME_DIR/chrome.zip"
        write_log "✅ Chrome for Testing installed"
    else
        write_log "❌ Error: Failed to download Chrome for Testing"
        exit 1
    fi

    # Verify it exists now
    if [[ ! -x "$CHROME_BIN" ]]; then
        write_log "❌ Error: Chrome binary still not found after download"
        exit 1
    fi
fi

write_log "Using Chrome for Testing: $(basename "$(dirname "$CHROME_BIN")")"

# Check for authenticated profile template
TEMPLATE_DIR="$HOME/.contextfort/profile-template"
if [[ -d "$TEMPLATE_DIR" ]]; then
    write_log "🔑 Found authenticated profile template, cloning..."
    cp -r "$TEMPLATE_DIR" "$PROFILE_DIR"
    write_log "✅ Profile cloned (login state preserved)"

    # Update session ID in cloned profile
    echo "$SESSION_ID" > "$PROFILE_DIR/contextfort-session-id.txt"
else
    write_log "ℹ️  No auth template found (will need to login)"
    write_log "   Run: $PLUGIN_DIR/bin/setup-auth.sh to set up persistent login"

    # Create fresh profile
    mkdir -p "$PROFILE_DIR"
    echo "$SESSION_ID" > "$PROFILE_DIR/contextfort-session-id.txt"
fi

write_log "🚀 Starting ContextFort isolated session"
write_log "Session ID: $SESSION_ID"
write_log "Profile: $PROFILE_DIR"

# Prepare extensions for loading (if not already in cloned profile)
write_log "Preparing extensions..."

# ContextFort extension (unpacked from plugin)
CONTEXTFORT_EXT_DIR="$PLUGIN_DIR/extension"
if [[ ! -d "$PROFILE_DIR/ContextFortExtension" ]]; then
    if [[ -d "$CONTEXTFORT_EXT_DIR" ]]; then
        cp -r "$CONTEXTFORT_EXT_DIR" "$PROFILE_DIR/ContextFortExtension"
        write_log "✅ ContextFort extension prepared"
    else
        write_log "❌ ERROR: ContextFort extension not found"
        exit 1
    fi
else
    write_log "✅ ContextFort extension (from template)"
fi

# Claude-in-Chrome extension (from user's Chrome profile)
CLAUDE_EXT_SOURCE="/Users/ashwin/Library/Application Support/Google/Chrome/Profile 1/Extensions/fcoeoabgfenejglbffodgkkbkcdhcgfn/1.0.40_0"
if [[ ! -d "$PROFILE_DIR/ClaudeInChrome" ]]; then
    if [[ -d "$CLAUDE_EXT_SOURCE" ]]; then
        cp -r "$CLAUDE_EXT_SOURCE" "$PROFILE_DIR/ClaudeInChrome"
        write_log "✅ Claude-in-Chrome extension prepared"
    else
        write_log "⚠️  Warning: Claude-in-Chrome not found"
    fi
else
    write_log "✅ Claude-in-Chrome extension (from template)"
fi

# Create session metadata
cat > "$SESSION_FILE" <<EOF
{
  "session_id": "${SESSION_ID}",
  "profile_dir": "${PROFILE_DIR}",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "ended_at": null,
  "status": "active",
  "chrome_pid": null,
  "events_count": 0,
  "screenshots_count": 0
}
EOF

write_log "✅ Session metadata created"

# Launch Chrome with isolated profile
write_log "Launching Chrome..."

# Build extensions list for loading
EXTENSIONS_TO_LOAD="$PROFILE_DIR/ContextFortExtension"
if [[ -d "$PROFILE_DIR/ClaudeInChrome" ]]; then
    EXTENSIONS_TO_LOAD="$EXTENSIONS_TO_LOAD,$PROFILE_DIR/ClaudeInChrome"
    write_log "Loading both ContextFort and Claude-in-Chrome"
else
    write_log "Loading only ContextFort"
fi

"$CHROME_BIN" \
    --user-data-dir="$PROFILE_DIR" \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-networking \
    --disable-sync \
    --disable-translate \
    --disable-features=TranslateUI,PasswordImport \
    --disable-default-apps \
    --disable-component-update \
    --use-mock-keychain \
    --password-store=basic \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --enable-features=VaapiVideoDecoder \
    --disable-software-rasterizer \
    --num-raster-threads=4 \
    --window-size=1920,1080 \
    --load-extension="$EXTENSIONS_TO_LOAD" \
    --disable-extensions-except="$EXTENSIONS_TO_LOAD" \
    "about:blank" \
    > "$CONTEXTFORT_DIR/logs/chrome-${SESSION_ID}.log" 2>&1 &

CHROME_PID=$!

# Save PID and path for cleanup
echo "$CHROME_PID" > "/tmp/contextfort-${SESSION_ID}.pid"
echo "$PROFILE_DIR" > "/tmp/contextfort-${SESSION_ID}.path"

# Update session with PID
sed -i.bak "s/\"chrome_pid\": null/\"chrome_pid\": $CHROME_PID/" "$SESSION_FILE"
rm -f "${SESSION_FILE}.bak"

write_log "✅ Chrome launched (PID: $CHROME_PID)"

# Wait for Chrome to be ready
write_log "Waiting for Chrome to be ready..."
for i in {1..20}; do
    sleep 0.5
    if kill -0 "$CHROME_PID" 2>/dev/null; then
        write_log "✅ Chrome is ready (PID: $CHROME_PID)"
        break
    fi
done

# Notify dashboard
curl -X POST http://localhost:8080/api/sessions \
    -H "Content-Type: application/json" \
    -d @"$SESSION_FILE" \
    > /dev/null 2>&1 || write_log "⚠️  Dashboard not running (sessions won't sync)"

write_log "✅ Isolated Chrome session ready!"
write_log "Dashboard: http://localhost:8080/sessions/${SESSION_ID}"

# Set up cleanup trap (in case script is killed)
# Note: Profile cleanup is handled by the background monitor process below
trap "write_log '🧹 Launcher script exiting'" EXIT

# Monitor Chrome process in background
(
    # Poll until Chrome process exits
    while kill -0 "$CHROME_PID" 2>/dev/null; do
        sleep 2
    done

    write_log "Chrome process ended (PID: $CHROME_PID)"

    # Mark session as ended
    ENDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    sed -i.bak "s/\"ended_at\": null/\"ended_at\": \"$ENDED_AT\"/" "$SESSION_FILE"
    sed -i.bak "s/\"status\": \"active\"/\"status\": \"ended\"/" "$SESSION_FILE"
    rm -f "${SESSION_FILE}.bak"

    # Cleanup
    write_log "🗑️  Cleaning up: $PROFILE_DIR"
    rm -rf "$PROFILE_DIR"
    rm -f "/tmp/contextfort-${SESSION_ID}.pid"
    rm -f "/tmp/contextfort-${SESSION_ID}.path"

    write_log "✅ Session ${SESSION_ID} cleanup complete"
) &

exit 0
