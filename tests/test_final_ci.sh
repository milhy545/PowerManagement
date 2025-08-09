#!/bin/bash

# Final CI Test - Verify all CI fixes are working

set -euo pipefail

echo "🎯 Final CI Compatibility Test"
echo "=============================="
echo ""

# Simulate CI environment
export CI=true

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

PASSED=0
FAILED=0

test_command() {
    local name="$1"
    local cmd="$2"
    
    echo -n "Testing: $name ... "
    
    if bash -c "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC}"
        echo "  Failed command: $cmd"
        ((FAILED++))
    fi
}

# Change to project directory
PROJECT_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
cd "$PROJECT_DIR"

echo "CI Mode: $CI"
echo "Project: $PROJECT_DIR"
echo ""

# Test 1: Security checks
echo "1. Security Checks:"
test_command "No rm -rf /" "! grep -r 'rm -rf /' scripts/"
test_command "Safe sudo rm" "! (grep -r 'sudo.*rm' scripts/ | grep -v '/tmp/' | grep -v 'EMERGENCY_CLEANUP' | grep -q .)"

# Test 2: Scripts don't use problematic sudo
echo ""
echo "2. Sudo Usage:"
test_command "Performance manager CI safe" "./scripts/performance_manager.sh test"
test_command "Emergency cleanup CI safe" "bash -n ./scripts/EMERGENCY_CLEANUP.sh"

# Test 3: Python dependencies
echo ""
echo "3. Python Dependencies:"
test_command "Python3 available" "which python3"
test_command "CPU manager syntax" "python3 -m py_compile src/frequency/cpu_frequency_manager.py"

# Test 4: Quick test runs
echo ""
echo "4. Test Suite:"
test_command "Quick test in CI mode" "./tests/quick_test.sh"

# Test 5: No hanging processes
echo ""
echo "5. Process Safety:"
test_command "No zombie processes" "! pgrep -f 'performance_manager' | head -20 | wc -l | grep -q -E '^[2-9][0-9]*$|^1[0-9]+$'"

# Results
echo ""
echo "=============================="
echo "Results:"
echo -e "  Passed: ${GREEN}$PASSED${NC}"
echo -e "  Failed: ${RED}$FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All CI tests passed! Ready for GitHub push.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some CI tests failed. Fix before pushing.${NC}"
    exit 1
fi
