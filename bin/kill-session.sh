#!/bin/bash
#
# ContextFort Remote Kill Switch
# Terminate active Chrome sessions by session-id or PID
#

set -euo pipefail

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONTEXTFORT_DIR="$HOME/.contextfort"
SESSIONS_DIR="$CONTEXTFORT_DIR/sessions"
LOGS_DIR="$CONTEXTFORT_DIR/logs"

# Usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Terminate active ContextFort Chrome sessions.

OPTIONS:
    --session-id <id>    Kill specific session by ID
    --all                Kill all active sessions
    --list               List active sessions
    -h, --help           Show this help

EXAMPLES:
    $(basename "$0") --session-id contextfort-chrome-12345
    $(basename "$0") --all
    $(basename "$0") --list

EOF
    exit 1
}

# List active sessions
list_sessions() {
    echo "Active ContextFort Sessions:"
    echo "============================"
    echo ""

    local found=0

    for pid_file in /tmp/contextfort-*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            local session_id=$(basename "$pid_file" .pid)

            # Check if process is still running
            if kill -0 "$pid" 2>/dev/null; then
                found=1
                echo "Session: $session_id"
                echo "  PID: $pid"
                echo "  Profile: /tmp/$session_id"

                # Check session metadata if exists
                if [[ -f "$SESSIONS_DIR/${session_id}.json" ]]; then
                    local started=$(grep -o '"started_at":"[^"]*"' "$SESSIONS_DIR/${session_id}.json" | cut -d'"' -f4)
                    echo "  Started: $started"
                fi

                echo ""
            else
                # Stale PID file, clean up
                rm -f "$pid_file"
            fi
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "No active sessions found."
    fi
}

# Kill specific session
kill_session() {
    local session_id="$1"
    local pid_file="/tmp/${session_id}.pid"

    if [[ ! -f "$pid_file" ]]; then
        echo "❌ Error: Session '$session_id' not found"
        echo ""
        echo "Active sessions:"
        list_sessions
        exit 1
    fi

    local pid=$(cat "$pid_file")

    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "⚠️  Session '$session_id' is not running (stale PID file)"
        rm -f "$pid_file"
        exit 0
    fi

    echo "🔪 Terminating session: $session_id (PID: $pid)"

    # Try graceful shutdown first
    kill "$pid" 2>/dev/null || true
    sleep 1

    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        echo "   Force killing..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    # Wait for termination
    local timeout=5
    while kill -0 "$pid" 2>/dev/null && [[ $timeout -gt 0 ]]; do
        sleep 1
        ((timeout--))
    done

    if kill -0 "$pid" 2>/dev/null; then
        echo "❌ Failed to terminate session"
        exit 1
    fi

    # Clean up
    rm -f "$pid_file"
    rm -rf "/tmp/$session_id"

    # Update session metadata
    if [[ -f "$SESSIONS_DIR/${session_id}.json" ]]; then
        # Mark as terminated
        local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        sed -i.bak "s/\"status\": \"active\"/\"status\": \"terminated\"/" "$SESSIONS_DIR/${session_id}.json"
        sed -i.bak "s/\"ended_at\": null/\"ended_at\": \"$now\"/" "$SESSIONS_DIR/${session_id}.json"
        rm -f "$SESSIONS_DIR/${session_id}.json.bak"
    fi

    echo "✅ Session terminated"

    # Log termination
    mkdir -p "$LOGS_DIR"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] KILL: Session $session_id terminated by kill-session.sh" >> "$LOGS_DIR/kill-switch.log"
}

# Kill all sessions
kill_all_sessions() {
    echo "🔪 Terminating all ContextFort sessions..."
    echo ""

    local count=0

    for pid_file in /tmp/contextfort-*.pid; do
        if [[ -f "$pid_file" ]]; then
            local session_id=$(basename "$pid_file" .pid)
            kill_session "$session_id"
            ((count++))
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo "No active sessions to terminate."
    else
        echo ""
        echo "✅ Terminated $count session(s)"
    fi
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    case "$1" in
        --list)
            list_sessions
            ;;
        --session-id)
            if [[ -z "${2:-}" ]]; then
                echo "❌ Error: --session-id requires a session ID"
                exit 1
            fi
            kill_session "$2"
            ;;
        --all)
            kill_all_sessions
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "❌ Error: Unknown option '$1'"
            usage
            ;;
    esac
}

main "$@"
