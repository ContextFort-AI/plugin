#!/bin/bash
#
# ContextFort Plugin Test Suite
# Tests all components of the plugin
#

set -euo pipefail

PLUGIN_DIR="$HOME/.claude/plugins/contextfort"
CONTEXTFORT_DIR="$HOME/.contextfort"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

echo "🧪 ContextFort Plugin Test Suite"
echo "================================="
echo ""

# Test function
test_component() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Testing $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Plugin directory exists
test_component "Plugin directory" "[[ -d '$PLUGIN_DIR' ]]"

# Test 2: Plugin.json exists and valid
test_component "plugin.json" "[[ -f '$PLUGIN_DIR/plugin.json' ]] && jq empty '$PLUGIN_DIR/plugin.json'"

# Test 3: Hooks exist and executable
test_component "PreToolUse hook" "[[ -x '$PLUGIN_DIR/hooks/pre-tool-use.sh' ]]"
test_component "SessionEnd hook" "[[ -x '$PLUGIN_DIR/hooks/session-end.sh' ]]"

# Test 4: Bin scripts exist and executable
test_component "launch-chrome.sh" "[[ -x '$PLUGIN_DIR/bin/launch-chrome.sh' ]]"
test_component "status.sh" "[[ -x '$PLUGIN_DIR/bin/status.sh' ]]"
test_component "cleanup.sh" "[[ -x '$PLUGIN_DIR/bin/cleanup.sh' ]]"
test_component "dashboard.sh" "[[ -x '$PLUGIN_DIR/bin/dashboard.sh' ]]"

# Test 5: Extension exists
test_component "Extension directory" "[[ -d '$PLUGIN_DIR/extension' ]]"
test_component "Extension manifest" "[[ -f '$PLUGIN_DIR/extension/manifest.json' ]]"
test_component "Extension background.js" "[[ -f '$PLUGIN_DIR/extension/background.js' ]]"
test_component "Extension content.js" "[[ -f '$PLUGIN_DIR/extension/content.js' ]]"

# Test 6: ContextFort directory structure
test_component "ContextFort directory" "[[ -d '$CONTEXTFORT_DIR' ]]"
test_component "Sessions directory" "[[ -d '$CONTEXTFORT_DIR/sessions' ]]"
test_component "Logs directory" "[[ -d '$CONTEXTFORT_DIR/logs' ]]"

# Test 7: Chrome binary exists
echo -n "Testing Chrome binary... "
CHROME_FOUND=false
if [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
    CHROME_FOUND=true
elif command -v google-chrome &> /dev/null; then
    CHROME_FOUND=true
elif command -v chromium-browser &> /dev/null; then
    CHROME_FOUND=true
fi

if $CHROME_FOUND; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((TESTS_FAILED++))
fi

# Test 8: Hook can be executed (dry run)
echo -n "Testing hook execution... "
if "$PLUGIN_DIR/hooks/pre-tool-use.sh" "test" "{}" 2>&1 | grep -q "Not a browser tool"; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((TESTS_FAILED++))
fi

# Test 9: Status script works
echo -n "Testing status command... "
if "$PLUGIN_DIR/bin/status.sh" 2>&1 | grep -q "ContextFort Status"; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((TESTS_FAILED++))
fi

# Test 10: Dashboard health check (if running)
echo -n "Testing dashboard connection... "
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS (Dashboard running)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  SKIP (Dashboard not running)${NC}"
fi

echo ""
echo "Results:"
echo "--------"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    echo ""
    echo "ContextFort is ready to use!"
    echo "Try: /contextfort status"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo ""
    echo "Please check the installation and try again."
    echo "See: $PLUGIN_DIR/README.md"
    exit 1
fi
