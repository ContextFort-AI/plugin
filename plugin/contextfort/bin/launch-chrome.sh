#!/bin/bash
#
# ContextFort Chrome Launcher
# Launches ephemeral Chrome instance with monitoring
#

set -euo pipefail

# Configuration
CONTEXTFORT_DIR="$HOME/.contextfort"
PLUGIN_DIR="$HOME/.claude/plugins/contextfort"
SESSION_ID=$(date +%s)
PROFILE_DIR="/tmp/contextfort-${SESSION_ID}"
LOG_FILE="$CONTEXTFORT_DIR/logs/launch.log"
SESSION_FILE="$CONTEXTFORT_DIR/sessions/${SESSION_ID}.json"

# Chrome binary paths (try multiple locations)
CHROME_PATHS=(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    "/usr/bin/google-chrome"
    "/usr/bin/chromium-browser"
    "/usr/bin/chromium"
)

# Find Chrome binary
find_chrome() {
    for path in "${CHROME_PATHS[@]}"; do
        if [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    echo "❌ Error: Chrome not found in standard locations" >&2
    return 1
}

CHROME_BIN=$(find_chrome)

# Ensure directories exist
mkdir -p "$CONTEXTFORT_DIR/"{sessions,logs}
mkdir -p "$PROFILE_DIR"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting ContextFort isolated session"
log "Session ID: $SESSION_ID"
log "Profile: $PROFILE_DIR"

# Prepare extension
EXTENSION_DIR="$PLUGIN_DIR/extension"
if [[ -d "$EXTENSION_DIR" ]]; then
    # Copy extension to profile (for loading)
    cp -r "$EXTENSION_DIR" "$PROFILE_DIR/ContextFortExtension"
    log "✅ Extension prepared"
else
    log "⚠️  Warning: Extension not found at $EXTENSION_DIR"
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

log "✅ Session metadata created"

# Launch Chrome with isolated profile
log "Launching Chrome..."

"$CHROME_BIN" \
    --user-data-dir="$PROFILE_DIR" \
    --remote-debugging-port=9222 \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-networking \
    --disable-sync \
    --disable-translate \
    --disable-features=TranslateUI \
    --disable-default-apps \
    --no-default-browser-check \
    --disable-component-update \
    --window-size=1920,1080 \
    --load-extension="$PROFILE_DIR/ContextFortExtension" \
    "about:blank" \
    > "$CONTEXTFORT_DIR/logs/chrome-${SESSION_ID}.log" 2>&1 &

CHROME_PID=$!

# Save PID and path for cleanup
echo "$CHROME_PID" > "/tmp/contextfort-${SESSION_ID}.pid"
echo "$PROFILE_DIR" > "/tmp/contextfort-${SESSION_ID}.path"

# Update session with PID
sed -i.bak "s/\"chrome_pid\": null/\"chrome_pid\": $CHROME_PID/" "$SESSION_FILE"
rm -f "${SESSION_FILE}.bak"

log "✅ Chrome launched (PID: $CHROME_PID)"

# Wait for Chrome to be ready
log "Waiting for Chrome to be ready..."
for i in {1..20}; do
    sleep 0.5
    if lsof -i:9222 > /dev/null 2>&1; then
        log "✅ Chrome is ready (CDP on port 9222)"
        break
    fi
done

# Notify dashboard
curl -X POST http://localhost:8080/api/sessions \
    -H "Content-Type: application/json" \
    -d @"$SESSION_FILE" \
    > /dev/null 2>&1 || log "⚠️  Dashboard not running (sessions won't sync)"

log "✅ Isolated Chrome session ready!"
log "Dashboard: http://localhost:8080/sessions/${SESSION_ID}"

# Set up cleanup trap (in case script is killed)
trap "log '🧹 Cleanup trap triggered'; rm -rf '$PROFILE_DIR' 2>/dev/null || true" EXIT

# Monitor Chrome process in background
(
    wait "$CHROME_PID" 2>/dev/null || true
    log "Chrome process ended (PID: $CHROME_PID)"

    # Mark session as ended
    ENDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    sed -i.bak "s/\"ended_at\": null/\"ended_at\": \"$ENDED_AT\"/" "$SESSION_FILE"
    sed -i.bak "s/\"status\": \"active\"/\"status\": \"ended\"/" "$SESSION_FILE"
    rm -f "${SESSION_FILE}.bak"

    # Cleanup
    log "🗑️  Cleaning up: $PROFILE_DIR"
    rm -rf "$PROFILE_DIR"
    rm -f "/tmp/contextfort-${SESSION_ID}.pid"
    rm -f "/tmp/contextfort-${SESSION_ID}.path"

    log "✅ Session ${SESSION_ID} cleanup complete"
) &

exit 0
