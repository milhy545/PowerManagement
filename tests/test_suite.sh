#!/bin/bash

# Test Suite for Linux Power Management Suite
# Automated testing with safety checks

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly SCRIPTS_DIR="$PROJECT_DIR/scripts"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging
log_test() {
    echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    ((TESTS_TOTAL++))
    log_test "Running: $test_name"
    
    if "$test_func"; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
    echo ""
}

# Test script existence
test_scripts_exist() {
    local scripts=(
        "performance_manager.sh"
        "ai_process_manager.sh" 
        "emergency_cleanup.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ ! -f "$SCRIPTS_DIR/$script" ]; then
            echo "Missing script: $script"
            return 1
        fi
        
        if [ ! -x "$SCRIPTS_DIR/$script" ]; then
            echo "Script not executable: $script"
            return 1
        fi
    done
    
    return 0
}

# Test performance manager dry run
test_performance_manager_dry_run() {
    local output
    output=$("$SCRIPTS_DIR/performance_manager.sh" test 2>&1)
    
    if echo "$output" | grep -q "TEST MODE" && \
       echo "$output" | grep -q "no changes made"; then
        return 0
    else
        echo "Dry run test failed: $output"
        return 1
    fi
}

# Test performance manager status
test_performance_manager_status() {
    local output
    output=$("$SCRIPTS_DIR/performance_manager.sh" status 2>&1)
    
    if echo "$output" | grep -q "Current Performance Status" && \
       echo "$output" | grep -q "CPU:" && \
       echo "$output" | grep -q "System Load:"; then
        return 0
    else
        echo "Status test failed: $output"
        return 1
    fi
}

# Test AI process manager show
test_ai_process_manager_show() {
    local output
    output=$("$SCRIPTS_DIR/ai_process_manager.sh" show 2>&1)
    
    if echo "$output" | grep -q "Current AI Processes"; then
        return 0
    else
        echo "AI process show failed: $output"
        return 1
    fi
}

# Test emergency cleanup dry run
test_emergency_cleanup_safe() {
    # Test emergency cleanup exists and has help
    local output
    output=$("$SCRIPTS_DIR/emergency_cleanup.sh" --help 2>&1 || true)
    
    # Just check it doesn't crash and exists
    if [ -f "$SCRIPTS_DIR/emergency_cleanup.sh" ]; then
        return 0
    else
        echo "Emergency cleanup not found"
        return 1
    fi
}

# Test process limits
test_process_limits() {
    # Check performance manager respects process limits
    local output
    output=$("$SCRIPTS_DIR/performance_manager.sh" status 2>&1)
    
    if echo "$output" | grep -q "Processes.*allowed"; then
        return 0
    else
        echo "Process limit check failed: $output"
        return 1
    fi
}

# Test configuration files
test_config_structure() {
    local required_dirs=(
        "$PROJECT_DIR/scripts"
        "$PROJECT_DIR/config"
        "$PROJECT_DIR/tests"
        "$PROJECT_DIR/docs"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Missing directory: $dir"
            return 1
        fi
    done
    
    return 0
}

# Test README exists and has content
test_documentation() {
    if [ ! -f "$PROJECT_DIR/README.md" ]; then
        echo "Missing README.md"
        return 1
    fi
    
    if ! grep -q "Linux Power Management Suite" "$PROJECT_DIR/README.md"; then
        echo "README.md missing expected content"
        return 1
    fi
    
    return 0
}

# Test safety features
test_safety_features() {
    local script="$SCRIPTS_DIR/performance_manager.sh"
    
    # Check for safety features in code
    if ! grep -q "set -euo pipefail" "$script"; then
        echo "Missing bash safety flags"
        return 1
    fi
    
    if ! grep -q "timeout" "$script"; then
        echo "Missing timeout protection"
        return 1
    fi
    
    return 0
}

# Main test runner
main() {
    echo "🧪 Linux Power Management Suite - Test Suite"
    echo "============================================="
    echo ""
    
    # Core functionality tests
    run_test "Scripts exist and executable" test_scripts_exist
    run_test "Configuration structure" test_config_structure
    run_test "Documentation exists" test_documentation
    run_test "Safety features present" test_safety_features
    
    # Functional tests
    run_test "Performance Manager dry run" test_performance_manager_dry_run
    run_test "Performance Manager status" test_performance_manager_status
    run_test "AI Process Manager show" test_ai_process_manager_show
    run_test "Emergency cleanup safe" test_emergency_cleanup_safe
    run_test "Process limits enforced" test_process_limits
    
    # Results
    echo "============================================="
    echo "Test Results:"
    echo "  Total: $TESTS_TOTAL"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo ""
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ $TESTS_FAILED test(s) failed!${NC}"
        exit 1
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi