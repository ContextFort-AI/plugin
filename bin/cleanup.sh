#!/bin/bash
#
# ContextFort Manual Cleanup
# Force cleanup of all sessions
#

set -euo pipefail

CONTEXTFORT_DIR="$HOME/.contextfort"

echo "🧹 ContextFort Manual Cleanup"
echo "============================="
echo ""

cleanup_count=0

# Find all PID files
for pid_file in /tmp/contextfort-*.pid; do
    if [[ ! -f "$pid_file" ]]; then
        continue
    fi

    SESSION_ID=$(basename "$pid_file" .pid | sed 's/contextfort-//')
    PID=$(cat "$pid_file" 2>/dev/null || echo "")

    echo "Cleaning up session $SESSION_ID..."

    # Kill Chrome process if still running
    if [[ -n "$PID" ]] && ps -p "$PID" > /dev/null 2>&1; then
        echo "  Stopping Chrome (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 1
        kill -9 "$PID" 2>/dev/null || true
    fi

    # Remove profile directory
    PROFILE_PATH_FILE="/tmp/contextfort-${SESSION_ID}.path"
    if [[ -f "$PROFILE_PATH_FILE" ]]; then
        PROFILE_DIR=$(cat "$PROFILE_PATH_FILE" 2>/dev/null || echo "")

        if [[ -n "$PROFILE_DIR" ]] && [[ -d "$PROFILE_DIR" ]]; then
            echo "  Removing profile: $PROFILE_DIR"
            rm -rf "$PROFILE_DIR"
        fi

        rm -f "$PROFILE_PATH_FILE"
    fi

    # Remove PID file
    rm -f "$pid_file"

    # Update session metadata
    SESSION_FILE="$CONTEXTFORT_DIR/sessions/${SESSION_ID}.json"
    if [[ -f "$SESSION_FILE" ]]; then
        ENDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        sed -i.bak "s/\"status\": \"active\"/\"status\": \"ended\"/" "$SESSION_FILE"
        sed -i.bak "s/\"ended_at\": null/\"ended_at\": \"$ENDED_AT\"/" "$SESSION_FILE"
        rm -f "${SESSION_FILE}.bak"
    fi

    echo "  ✅ Cleaned up"
    echo ""

    ((cleanup_count++))
done

if [[ $cleanup_count -eq 0 ]]; then
    echo "No sessions to cleanup"
else
    echo "✅ Cleaned up $cleanup_count session(s)"
fi

echo ""
