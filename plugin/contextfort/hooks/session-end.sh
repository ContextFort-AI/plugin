#!/bin/bash
#
# ContextFort SessionEnd Hook
# Cleanup ephemeral sessions when Claude session ends
#

set -euo pipefail

CONTEXTFORT_DIR="$HOME/.contextfort"
LOG_FILE="$CONTEXTFORT_DIR/logs/cleanup.log"

# Ensure log directory exists
mkdir -p "$CONTEXTFORT_DIR/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🧹 Session end - starting cleanup..."

# Find all ContextFort PIDs
cleanup_count=0

for pid_file in /tmp/contextfort-*.pid; do
    if [[ ! -f "$pid_file" ]]; then
        continue
    fi

    PID=$(cat "$pid_file" 2>/dev/null || echo "")

    if [[ -z "$PID" ]]; then
        rm -f "$pid_file"
        continue
    fi

    # Check if process is still running
    if ps -p "$PID" > /dev/null 2>&1; then
        log "Chrome still running (PID: $PID), skipping..."
        continue
    fi

    # Process ended, cleanup
    SESSION_ID=$(basename "$pid_file" .pid | sed 's/contextfort-//')
    PROFILE_PATH_FILE="/tmp/contextfort-${SESSION_ID}.path"

    if [[ -f "$PROFILE_PATH_FILE" ]]; then
        PROFILE_DIR=$(cat "$PROFILE_PATH_FILE" 2>/dev/null)

        if [[ -n "$PROFILE_DIR" ]] && [[ -d "$PROFILE_DIR" ]]; then
            log "🗑️  Deleting profile: $PROFILE_DIR"
            rm -rf "$PROFILE_DIR"
            ((cleanup_count++))
        fi

        rm -f "$PROFILE_PATH_FILE"
    fi

    # Update session metadata
    SESSION_FILE="$CONTEXTFORT_DIR/sessions/${SESSION_ID}.json"
    if [[ -f "$SESSION_FILE" ]]; then
        # Mark as ended (using simple sed since jq might not be available)
        ENDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        sed -i.bak "s/\"status\": \"active\"/\"status\": \"ended\"/" "$SESSION_FILE"
        sed -i.bak "s/\"ended_at\": null/\"ended_at\": \"$ENDED_AT\"/" "$SESSION_FILE"
        rm -f "${SESSION_FILE}.bak"

        log "✅ Session ${SESSION_ID} marked as ended"
    fi

    # Remove PID file
    rm -f "$pid_file"
done

if [[ $cleanup_count -eq 0 ]]; then
    log "No sessions to cleanup"
else
    log "✅ Cleaned up $cleanup_count session(s)"
fi

# Notify dashboard of cleanup
curl -X POST http://localhost:8080/api/cleanup \
    -H "Content-Type: application/json" \
    -d "{\"cleaned\": $cleanup_count, \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" \
    2>/dev/null || log "⚠️  Dashboard not running"

exit 0
