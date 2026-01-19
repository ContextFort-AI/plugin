#!/bin/bash
#
# ContextFort Status Check
# Shows active sessions and system status
#

set -euo pipefail

CONTEXTFORT_DIR="$HOME/.contextfort"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🛡️  ContextFort Status"
echo "===================="
echo ""

# Check if Chrome is running
if lsof -ti:9222 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Isolated Chrome: Running (CDP on port 9222)${NC}"
    CHROME_RUNNING=true
else
    echo -e "${YELLOW}⚠️  Isolated Chrome: Not running${NC}"
    CHROME_RUNNING=false
fi

# Check if dashboard is running
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Dashboard: Running (http://localhost:8080)${NC}"
else
    echo -e "${YELLOW}⚠️  Dashboard: Not running${NC}"
fi

echo ""

# Check for active sessions
echo "Active Sessions:"
echo "----------------"

active_count=0

for pid_file in /tmp/contextfort-*.pid; do
    if [[ ! -f "$pid_file" ]]; then
        continue
    fi

    PID=$(cat "$pid_file" 2>/dev/null || echo "")

    if [[ -z "$PID" ]]; then
        continue
    fi

    if ps -p "$PID" > /dev/null 2>&1; then
        SESSION_ID=$(basename "$pid_file" .pid | sed 's/contextfort-//')
        PROFILE_PATH_FILE="/tmp/contextfort-${SESSION_ID}.path"
        PROFILE_DIR=$(cat "$PROFILE_PATH_FILE" 2>/dev/null || echo "unknown")

        SESSION_FILE="$CONTEXTFORT_DIR/sessions/${SESSION_ID}.json"

        if [[ -f "$SESSION_FILE" ]]; then
            STARTED_AT=$(grep -o '"started_at": "[^"]*"' "$SESSION_FILE" | cut -d'"' -f4)
            echo -e "${GREEN}  • Session $SESSION_ID${NC}"
            echo "    PID: $PID"
            echo "    Started: $STARTED_AT"
            echo "    Profile: $PROFILE_DIR"
            echo ""
        else
            echo -e "${GREEN}  • Session $SESSION_ID${NC} (PID: $PID)"
            echo ""
        fi

        ((active_count++))
    fi
done

if [[ $active_count -eq 0 ]]; then
    echo "  No active sessions"
    echo ""
fi

# Show recent sessions
echo "Recent Sessions (last 5):"
echo "-------------------------"

if [[ -d "$CONTEXTFORT_DIR/sessions" ]]; then
    session_files=($(ls -t "$CONTEXTFORT_DIR/sessions"/*.json 2>/dev/null | head -5))

    if [[ ${#session_files[@]} -eq 0 ]]; then
        echo "  No sessions found"
    else
        for session_file in "${session_files[@]}"; do
            SESSION_ID=$(basename "$session_file" .json)
            STATUS=$(grep -o '"status": "[^"]*"' "$session_file" | cut -d'"' -f4)
            STARTED=$(grep -o '"started_at": "[^"]*"' "$session_file" | cut -d'"' -f4)

            if [[ "$STATUS" == "active" ]]; then
                echo -e "  • ${GREEN}$SESSION_ID${NC} (active) - $STARTED"
            else
                echo "  • $SESSION_ID (ended) - $STARTED"
            fi
        done
    fi
else
    echo "  No sessions directory"
fi

echo ""
echo "Commands:"
echo "---------"
echo "  /contextfort cleanup   - Cleanup all sessions"
echo "  /contextfort dashboard - Open dashboard"
echo ""
