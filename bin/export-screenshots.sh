#!/bin/bash
#
# ContextFort Screenshot Exporter
# Export audit screenshots from Chrome storage to disk
#

set -euo pipefail

CONTEXTFORT_DIR="$HOME/.contextfort"
OUTPUT_DIR="$CONTEXTFORT_DIR/screenshots"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Export audit screenshots from ContextFort Chrome storage.

OPTIONS:
    --output <dir>      Output directory (default: ~/.contextfort/screenshots)
    --format <format>   Output format: jpeg (default), png
    --last-hours <N>    Only export screenshots from last N hours
    --with-metadata     Export metadata JSON alongside images
    -h, --help          Show this help

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --output /var/audit/screenshots
    $(basename "$0") --last-hours 24 --with-metadata

NOTES:
    - Screenshot capture is DISABLED by default (privacy concerns)
    - Enterprise admins must enable via extension settings
    - Requires Chrome storage access (via DevTools or extension API)

EOF
    exit 1
}

# Parse arguments
FORMAT="jpeg"
LAST_HOURS=""
WITH_METADATA=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_DIR="$2"
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
        --with-metadata)
            WITH_METADATA=true
            shift
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

echo "📸 ContextFort Screenshot Exporter"
echo "===================================="
echo ""

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

cat << 'INFO'
📋 Screenshot Export Instructions
==================================

ContextFort stores audit screenshots in Chrome's Local Storage.

⚠️  PRIVACY NOTICE:
Screenshot capture is DISABLED by default and must be explicitly
enabled by enterprise administrators.

To export screenshots:

METHOD 1: Via Chrome DevTools
------------------------------
1. Open ContextFort Chrome session
2. Open DevTools (Cmd+Option+I / Ctrl+Shift+I)
3. Go to: Application → Local Storage → chrome-extension://...
4. Find key: "screenshots"
5. Each screenshot has:
   - id: Unique identifier
   - timestamp: Capture time
   - url: Page URL
   - title: Page title
   - dataUrl: base64-encoded image (data:image/jpeg;base64,...)
6. Copy dataUrl values and decode:
   echo "<base64_data>" | base64 -d > screenshot.jpg

METHOD 2: Via Extension Export API
-----------------------------------
Enable export in extension settings, then:

  chrome.runtime.sendMessage({type: 'EXPORT_SCREENSHOTS'}, (response) => {
    response.screenshots.forEach(s => {
      // Download s.dataUrl as file
    });
  });

METHOD 3: Enable Screenshot Capture
------------------------------------
To enable automatic screenshot capture (enterprise only):

1. Set storage config:
   chrome.storage.local.set({
     screenshotConfig: {
       enabled: true,
       interval: 30000,      // 30 seconds
       quality: 80,          // JPEG quality
       maxWidth: 1920,       // Max width
       storageLimit: 100     // Max count
     }
   });

2. Screenshots will be captured every 30s
3. Export via methods above

SECURITY CONSIDERATIONS
-----------------------
✓ Screenshots may contain sensitive data
✓ Store in encrypted filesystem
✓ Set appropriate retention policy
✓ Comply with privacy regulations (GDPR, etc.)
✓ Notify users of screenshot capture

INFO

echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "💡 For automated export, integrate with extension API"
echo "   or use Chrome DevTools Protocol (CDP)"
echo ""

# Check if output directory is writable
if [[ ! -w "$OUTPUT_DIR" ]]; then
    echo "❌ Error: Output directory is not writable: $OUTPUT_DIR"
    exit 1
fi

echo "✅ Output directory ready"
echo ""
echo "Next steps:"
echo "1. Enable screenshot capture in extension settings"
echo "2. Run Agent Chrome session"
echo "3. Use DevTools or API to export screenshots"
echo "4. Screenshots will be saved to: $OUTPUT_DIR"
