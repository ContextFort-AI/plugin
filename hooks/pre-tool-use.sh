#!/bin/bash
#
# ContextFort PreToolUse Hook
# Intercepts browser tool calls and launches isolated Chrome
#

set -euo pipefail

TOOL_NAME="${1:-}"
TOOL_PARAMS="${2:-}"

# Configuration
CONTEXTFORT_DIR="$HOME/.contextfort"
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT}"
LOG_FILE="$CONTEXTFORT_DIR/logs/hook.log"

# Ensure directories exist
mkdir -p "$CONTEXTFORT_DIR/"{sessions,logs}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if this is a browser-related tool
is_browser_tool() {
    local tool="$1"

    # Match Claude in Chrome tools and other browser automation
    if [[ "$tool" =~ (mcp__claude-in-chrome__|chrome|browser|navigate|screenshot|playwright|puppeteer) ]]; then
        return 0
    fi

    return 1
}

# Check if isolated Chrome is running
is_chrome_running() {
    # Check for any active ContextFort Chrome sessions
    for pid_file in /tmp/contextfort-*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file" 2>/dev/null)
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                return 0
            fi
        fi
    done
    return 1
}

# Main logic
main() {
    log "Hook triggered for tool: $TOOL_NAME"

    # Check if this is a browser tool
    if ! is_browser_tool "$TOOL_NAME"; then
        log "Not a browser tool, allowing normally"
        exit 0
    fi

    log "🛡️  Browser tool detected: $TOOL_NAME"

    # Check if isolated Chrome is already running
    if is_chrome_running; then
        log "✅ Isolated Chrome already running"
        exit 0
    fi

    log "🚀 Launching isolated Chrome..."

    # Launch isolated Chrome
    if [[ -x "$PLUGIN_DIR/bin/launch-chrome.sh" ]]; then
        "$PLUGIN_DIR/bin/launch-chrome.sh" >> "$LOG_FILE" 2>&1 &

        # Wait for Chrome to be ready (max 10 seconds)
        for i in {1..20}; do
            sleep 0.5
            if is_chrome_running; then
                log "✅ Isolated Chrome ready"
                exit 0
            fi
        done

        log "⚠️  Warning: Chrome may not be fully ready yet"
        exit 0
    else
        log "❌ Error: launch-chrome.sh not found or not executable"
        exit 1
    fi
}

# Run main function
main "$@"
