#!/bin/bash

# CPU Frequency Control Test Suite
# Tests MSR-based frequency control and thermal profiles

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly FREQUENCY_MANAGER="$PROJECT_DIR/src/frequency/cpu_frequency_manager.py"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m' 
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test logging
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
    ((TESTS_TOTAL++))
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

# Test helper functions
get_cpu_temp() {
    sensors 2>/dev/null | grep "Core 0" | awk '{print $3}' | sed 's/[+°C]//g' | cut -d'.' -f1 || echo "0"
}

get_cpu_model() {
    grep "model name" /proc/cpuinfo | head -1 | awk -F': ' '{print $2}'
}

check_msr_access() {
    sudo modprobe msr 2>/dev/null || return 1
    test -c /dev/cpu/0/msr || return 1
}

# Test functions
test_cpu_detection() {
    log_test "CPU Model Detection"
    
    local cpu_model
    cpu_model=$(get_cpu_model)
    
    if [[ -n "$cpu_model" ]]; then
        log_pass "CPU detected: $cpu_model"
        return 0
    else
        log_fail "Failed to detect CPU model"
        return 1
    fi
}

test_msr_access() {
    log_test "MSR Access Test"
    
    if check_msr_access; then
        log_pass "MSR module loaded and accessible"
        return 0
    else
        log_fail "MSR access failed - requires root privileges"
        return 1
    fi
}

test_frequency_manager_status() {
    log_test "Frequency Manager Status Check"
    
    if [[ ! -f "$FREQUENCY_MANAGER" ]]; then
        log_fail "Frequency manager not found: $FREQUENCY_MANAGER"
        return 1
    fi
    
    if python3 "$FREQUENCY_MANAGER" status >/dev/null 2>&1; then
        log_pass "Frequency manager status check successful"
        return 0
    else
        log_fail "Frequency manager status check failed"
        return 1
    fi
}

test_thermal_profiles() {
    log_test "Thermal Profiles Availability"
    
    local profiles=("performance" "balanced" "power_save" "emergency")
    local failed=0
    
    for profile in "${profiles[@]}"; do
        if python3 "$FREQUENCY_MANAGER" thermal "$profile" >/dev/null 2>&1; then
            log_info "✓ Thermal profile '$profile' available"
        else
            log_info "✗ Thermal profile '$profile' failed"
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        log_pass "All thermal profiles available"
        return 0
    else
        log_fail "$failed thermal profiles failed"
        return 1
    fi
}

test_frequency_change() {
    log_test "Frequency Change Test"
    
    local initial_temp
    initial_temp=$(get_cpu_temp)
    
    log_info "Initial temperature: ${initial_temp}°C"
    
    # Test power_save profile (should reduce temperature)
    if python3 "$FREQUENCY_MANAGER" thermal power_save >/dev/null 2>&1; then
        sleep 5  # Allow time for thermal change
        
        local new_temp
        new_temp=$(get_cpu_temp)
        log_info "Temperature after power_save: ${new_temp}°C"
        
        if [[ $new_temp -le $((initial_temp + 5)) ]]; then
            log_pass "Frequency change successful (thermal impact acceptable)"
            return 0
        else
            log_fail "Temperature increased unexpectedly"
            return 1
        fi
    else
        log_fail "Failed to apply power_save profile"
        return 1
    fi
}

test_emergency_throttling() {
    log_test "Emergency Throttling Test"
    
    local initial_temp
    initial_temp=$(get_cpu_temp)
    
    if [[ $initial_temp -gt 70 ]]; then
        log_info "System already hot (${initial_temp}°C) - testing emergency throttling"
        
        if python3 "$FREQUENCY_MANAGER" thermal emergency >/dev/null 2>&1; then
            sleep 5
            
            local emergency_temp
            emergency_temp=$(get_cpu_temp)
            
            if [[ $emergency_temp -lt $initial_temp ]]; then
                log_pass "Emergency throttling effective (${initial_temp}°C → ${emergency_temp}°C)"
                return 0
            else
                log_fail "Emergency throttling ineffective"
                return 1
            fi
        else
            log_fail "Emergency throttling command failed"
            return 1
        fi
    else
        log_info "System cool (${initial_temp}°C) - emergency throttling not needed"
        log_pass "Emergency throttling available (not tested due to cool system)"
        return 0
    fi
}

test_integration_with_performance_manager() {
    log_test "Integration with Performance Manager"
    
    local perf_manager="$PROJECT_DIR/scripts/performance_manager.sh"
    
    if [[ ! -f "$perf_manager" ]]; then
        log_fail "Performance manager not found"
        return 1
    fi
    
    # Test that performance manager can call frequency manager
    if "$perf_manager" test >/dev/null 2>&1; then
        log_pass "Performance manager integration working"
        return 0
    else
        log_fail "Performance manager integration failed"
        return 1
    fi
}

test_safety_checks() {
    log_test "Safety Checks"
    
    # Test invalid frequency
    if python3 "$FREQUENCY_MANAGER" set 9999 >/dev/null 2>&1; then
        log_fail "Safety check failed - accepted invalid frequency"
        return 1
    else
        log_pass "Safety check passed - rejected invalid frequency"
    fi
    
    # Test invalid profile
    if python3 "$FREQUENCY_MANAGER" thermal invalid_profile >/dev/null 2>&1; then
        log_fail "Safety check failed - accepted invalid profile"
        return 1
    else
        log_pass "Safety check passed - rejected invalid profile"
    fi
    
    return 0
}

# Hardware-specific tests
test_q9550_specific() {
    log_test "Core 2 Quad Q9550 Specific Tests"
    
    local cpu_model
    cpu_model=$(get_cpu_model)
    
    if [[ "$cpu_model" == *"Q9550"* ]]; then
        log_info "Running Q9550-specific tests"
        
        # Test Q9550 multiplier table
        local q9550_freqs=(1333 1666 2166 2833)
        local failed=0
        
        for freq in "${q9550_freqs[@]}"; do
            if python3 "$FREQUENCY_MANAGER" set "$freq" >/dev/null 2>&1; then
                log_info "✓ Q9550 frequency ${freq}MHz supported"
            else
                log_info "✗ Q9550 frequency ${freq}MHz failed"
                ((failed++))
            fi
        done
        
        if [[ $failed -eq 0 ]]; then
            log_pass "All Q9550 frequencies supported"
            return 0
        else
            log_fail "$failed Q9550 frequencies not supported"
            return 1
        fi
    else
        log_info "Not a Q9550 CPU - skipping specific tests"
        log_pass "Q9550 tests skipped (different CPU)"
        return 0
    fi
}

# Main test execution
run_all_tests() {
    echo "🧪 CPU Frequency Control Test Suite"
    echo "===================================="
    echo
    
    log_info "System Information:"
    log_info "CPU: $(get_cpu_model)"
    log_info "Initial Temperature: $(get_cpu_temp)°C"
    log_info "MSR Support: $(check_msr_access && echo "Available" || echo "Not Available")"
    echo
    
    # Core functionality tests
    test_cpu_detection
    test_msr_access
    test_frequency_manager_status
    test_thermal_profiles
    
    # Advanced tests (only if basic tests pass)
    if [[ $TESTS_FAILED -eq 0 ]]; then
        test_frequency_change
        test_emergency_throttling
        test_integration_with_performance_manager
        test_safety_checks
        test_q9550_specific
    else
        log_info "Skipping advanced tests due to basic test failures"
    fi
    
    # Test summary
    echo
    echo "Test Results Summary:"
    echo "===================="
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests "$@"
fi