#!/bin/bash
#
# ContextFort Dashboard Launcher
# Opens the dashboard in default browser
#

set -euo pipefail

DASHBOARD_URL="http://localhost:8080"

echo "🖥️  Opening ContextFort Dashboard..."

# Check if dashboard is running
if ! curl -s "$DASHBOARD_URL/health" > /dev/null 2>&1; then
    echo "⚠️  Warning: Dashboard doesn't appear to be running"
    echo "   Expected at: $DASHBOARD_URL"
    echo ""
    echo "   To start the dashboard:"
    echo "   cd /Users/ashwin/agents-blocker/contextfort-dashboard"
    echo "   npm run dev"
    echo ""
    exit 1
fi

# Open in default browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    open "$DASHBOARD_URL"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "$DASHBOARD_URL"
else
    echo "Please open: $DASHBOARD_URL"
fi

echo "✅ Dashboard opened in browser"
