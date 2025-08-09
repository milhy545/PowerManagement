#!/bin/bash

# Test CI Compatibility - Simulate CI environment locally
# This helps debug CI issues without pushing to GitHub

set -euo pipefail

echo "🧪 CI Compatibility Test"
echo "========================"
echo ""

# Simulate CI environment
export CI=true

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local cmd="$2"
    
    echo -n "Testing: $name ... "
    
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Command: $cmd"
        echo "  Error: $?"
    fi
}

# Change to project directory
cd "$(dirname "$(dirname "$(readlink -f "$0")")")"

echo "Project directory: $(pwd)"
echo "CI mode: $CI"
echo ""

# Test 1: Python modules
echo "1. Python Dependencies:"
run_test "Import psutil" "python3 -c 'import psutil'"
run_test "Import aiohttp" "python3 -c 'import aiohttp' 2>/dev/null || echo 'aiohttp not required'"

# Test 2: Script permissions
echo ""
echo "2. Script Permissions:"
run_test "performance_manager.sh executable" "test -x scripts/performance_manager.sh"
run_test "ai_process_manager.sh executable" "test -x scripts/ai_process_manager.sh"
run_test "quick_test.sh executable" "test -x tests/quick_test.sh"

# Test 3: Quick test in CI mode
echo ""
echo "3. Quick Test Suite (CI mode):"
run_test "Quick test suite" "./tests/quick_test.sh"

# Test 4: CPU frequency manager in CI mode
echo ""
echo "4. CPU Frequency Manager (CI mode):"
run_test "CPU frequency manager status" "python3 src/frequency/cpu_frequency_manager.py status"

# Test 5: Performance manager test mode
echo ""
echo "5. Performance Manager:"
run_test "Performance manager test" "./scripts/performance_manager.sh test"

# Test 6: AI process manager show
echo ""
echo "6. AI Process Manager:"
run_test "AI process manager show" "./scripts/ai_process_manager.sh show"

# Results
echo ""
echo "========================"
echo "Test Results:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All CI compatibility tests passed!${NC}"
    echo "The code should work in GitHub Actions CI."
    exit 0
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo "Fix these issues before pushing to GitHub."
    exit 1
fi
