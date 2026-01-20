#!/bin/bash
#
# ContextFort DLP Log Exporter
# Export DLP clipboard events from Chrome storage to JSONL for SIEM ingestion
#

set -euo pipefail

CONTEXTFORT_DIR="$HOME/.contextfort"
OUTPUT_DIR="$CONTEXTFORT_DIR/logs"
OUTPUT_FILE="$OUTPUT_DIR/dlp-events.jsonl"

# Chrome user data directory (Agent Chrome profile location)
CHROME_PROFILE_PATTERN="/tmp/contextfort-*"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Export DLP clipboard events from ContextFort Chrome storage.

OPTIONS:
    --output <file>     Output file path (default: ~/.contextfort/logs/dlp-events.jsonl)
    --format <format>   Output format: jsonl (default), json, csv
    --last-hours <N>    Only export events from last N hours
    -h, --help          Show this help

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --output /var/log/contextfort-dlp.jsonl
    $(basename "$0") --format csv --last-hours 24

EOF
    exit 1
}

# Parse arguments
FORMAT="jsonl"
LAST_HOURS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --last-hours)
            LAST_HOURS="$2"
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

echo "🔍 ContextFort DLP Log Exporter"
echo "================================"
echo ""

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Find active Chrome profile with DLP data
FOUND_PROFILE=""

for profile_dir in $CHROME_PROFILE_PATTERN; do
    if [[ -d "$profile_dir/Default/Local Storage/leveldb" ]]; then
        FOUND_PROFILE="$profile_dir"
        break
    fi
done

if [[ -z "$FOUND_PROFILE" ]]; then
    echo "⚠️  No active ContextFort Chrome profile found"
    echo "   DLP events are stored in Chrome's Local Storage"
    echo "   Run Agent Chrome first, then try again"
    exit 1
fi

echo "✅ Found Chrome profile: $(basename "$FOUND_PROFILE")"
echo ""

# Note: Extracting from Chrome's Local Storage LevelDB requires special tools
# For now, document the manual export process

cat << 'INFO'
📋 DLP Event Export Instructions
==================================

ContextFort stores DLP events in Chrome's Local Storage.
To export them for SIEM ingestion:

METHOD 1: Via Chrome DevTools (Recommended)
--------------------------------------------
1. Open ContextFort Chrome session
2. Open DevTools (Cmd+Option+I on Mac, Ctrl+Shift+I on Windows)
3. Go to: Application → Local Storage → chrome-extension://...
4. Find key: "dlp_events"
5. Copy the JSON value
6. Save to file

METHOD 2: Via Extension API
----------------------------
Create a simple export page in the extension:

  chrome.storage.local.get(['dlp_events'], (result) => {
    const events = result.dlp_events || [];
    const jsonl = events.map(e => JSON.stringify(e)).join('\n');
    // Download as file
  });

METHOD 3: Automated Export (Future)
------------------------------------
We're working on automated export via native messaging host.
This will allow real-time SIEM ingestion.

CURRENT WORKAROUND
------------------
For now, DLP events are logged to console and can be viewed in:
  ~/.contextfort/logs/native-proxy-events.jsonl

Search for DLP-related events:
  grep "DLP" ~/.contextfort/logs/native-proxy-events.jsonl | jq '.'

INFO

echo ""
echo "💡 For automated SIEM integration, use the native proxy logs:"
echo "   File: ~/.contextfort/logs/native-proxy-events.jsonl"
echo "   Filter: event_type contains 'dlp' or 'clipboard'"
echo ""

# Check if native proxy logs have DLP events
if [[ -f "$CONTEXTFORT_DIR/logs/native-proxy-events.jsonl" ]]; then
    DLP_COUNT=$(grep -c "DLP" "$CONTEXTFORT_DIR/logs/native-proxy-events.jsonl" 2>/dev/null || echo "0")
    echo "📊 Found $DLP_COUNT DLP-related events in proxy logs"

    if [[ $DLP_COUNT -gt 0 ]]; then
        echo ""
        echo "Recent DLP events:"
        grep "DLP" "$CONTEXTFORT_DIR/logs/native-proxy-events.jsonl" | tail -5 | jq -r '. | "\(.timestamp) - \(.event_type)"'
    fi
fi
