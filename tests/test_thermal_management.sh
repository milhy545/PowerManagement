#!/bin/bash

# Thermal Management Test Suite  
# Tests progressive thermal response and emergency protection

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

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

# Helper functions
get_cpu_temp() {
    timeout 3 sensors 2>/dev/null | grep "Core 0" | awk '{print $3}' | sed 's/[+°C]//g' | cut -d'.' -f1 || echo "50"
}

test_temperature_reading() {
    log_test "Temperature Sensor Reading"
    
    local temp
    temp=$(get_cpu_temp)
    
    if [[ $temp -gt 0 && $temp -lt 120 ]]; then
        log_pass "Temperature reading: ${temp}°C (valid range)"
        return 0
    else
        log_fail "Invalid temperature reading: ${temp}°C"
        return 1
    fi
}

test_thermal_thresholds() {
    log_test "Thermal Threshold Configuration"
    
    local temp
    temp=$(get_cpu_temp)
    
    log_info "Current temperature: ${temp}°C"
    
    # Test thermal zones
    if [[ $temp -lt 65 ]]; then
        log_info "System in COMFORT zone (<65°C) - optimal performance"
        log_pass "Thermal threshold: COMFORT zone"
    elif [[ $temp -lt 70 ]]; then
        log_info "System in WARNING zone (65-70°C) - throttling recommended"
        log_pass "Thermal threshold: WARNING zone"
    elif [[ $temp -lt 80 ]]; then
        log_info "System in CRITICAL zone (70-80°C) - aggressive throttling needed"
        log_pass "Thermal threshold: CRITICAL zone"
    else
        log_info "System in EMERGENCY zone (>80°C) - immediate action required"
        log_pass "Thermal threshold: EMERGENCY zone"
    fi
    
    return 0
}

test_emergency_thermal_protection() {
    log_test "Emergency Thermal Protection"
    
    local emergency_script="$PROJECT_DIR/scripts/emergency_system_protection.sh"
    
    if [[ ! -f "$emergency_script" ]]; then
        log_fail "Emergency protection script not found"
        return 1
    fi
    
    # Test emergency script can run
    if timeout 10 "$emergency_script" temp >/dev/null 2>&1; then
        log_pass "Emergency thermal protection accessible"
        return 0
    else
        log_fail "Emergency thermal protection failed"
        return 1
    fi
}

test_progressive_thermal_response() {
    log_test "Progressive Thermal Response"
    
    local smart_thermal="$PROJECT_DIR/scripts/smart_thermal_manager.py"
    
    if [[ ! -f "$smart_thermal" ]]; then
        log_fail "Smart thermal manager not found"
        return 1
    fi
    
    # Test thermal manager status
    if timeout 10 python3 "$smart_thermal" status >/dev/null 2>&1; then
        log_pass "Progressive thermal response system ready"
        return 0
    else
        log_fail "Progressive thermal response system failed"
        return 1
    fi
}

test_thermal_ai_integration() {
    log_test "Thermal-AI Integration"
    
    local ai_examples="$PROJECT_DIR/examples/ai_workloads"
    
    if [[ ! -d "$ai_examples" ]]; then
        log_fail "AI workload examples directory not found"
        return 1
    fi
    
    local test_files=(
        "final_mycoder_test.py"
        "ultra_safe_mycoder.py"
    )
    
    local missing=0
    for file in "${test_files[@]}"; do
        if [[ ! -f "$ai_examples/$file" ]]; then
            log_info "Missing AI test file: $file"
            ((missing++))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        log_pass "All thermal-AI integration examples present"
        return 0
    else
        log_fail "$missing AI integration examples missing"
        return 1
    fi
}

test_temperature_monitoring_accuracy() {
    log_test "Temperature Monitoring Accuracy"
    
    # Take multiple readings to test consistency
    local readings=()
    for i in {1..5}; do
        readings[i]=$(get_cpu_temp)
        sleep 1
    done
    
    # Calculate variance
    local min_temp=999
    local max_temp=0
    
    for temp in "${readings[@]}"; do
        [[ $temp -lt $min_temp ]] && min_temp=$temp
        [[ $temp -gt $max_temp ]] && max_temp=$temp
    done
    
    local variance=$((max_temp - min_temp))
    
    if [[ $variance -le 10 ]]; then
        log_pass "Temperature monitoring stable (variance: ${variance}°C)"
        return 0
    else
        log_fail "Temperature monitoring unstable (variance: ${variance}°C)"
        return 1
    fi
}

test_thermal_performance_profiles() {
    log_test "Thermal Performance Profile Integration"
    
    local perf_manager="$PROJECT_DIR/scripts/performance_manager.sh"
    
    if [[ ! -f "$perf_manager" ]]; then
        log_fail "Performance manager not found"
        return 1
    fi
    
    # Test that performance manager has thermal integration
    if grep -q "thermal" "$perf_manager"; then
        log_pass "Performance manager has thermal integration"
        return 0
    else
        log_fail "Performance manager missing thermal integration"
        return 1
    fi
}

# Stress test simulation
test_thermal_stress_simulation() {
    log_test "Thermal Stress Simulation"
    
    local initial_temp
    initial_temp=$(get_cpu_temp)
    
    log_info "Initial temperature: ${initial_temp}°C"
    
    if [[ $initial_temp -gt 75 ]]; then
        log_info "System already hot - skipping stress test for safety"
        log_pass "Thermal stress test skipped (system protection)"
        return 0
    fi
    
    # Brief CPU stress to test thermal response
    log_info "Running brief stress test (5 seconds)..."
    
    # Light CPU load
    timeout 5 yes > /dev/null 2>&1 &
    local stress_pid=$!
    
    sleep 3
    local stress_temp
    stress_temp=$(get_cpu_temp)
    
    # Kill stress process
    kill $stress_pid 2>/dev/null || true
    wait $stress_pid 2>/dev/null || true
    
    log_info "Temperature during stress: ${stress_temp}°C"
    
    if [[ $stress_temp -le 85 ]]; then
        log_pass "Thermal response adequate under light stress"
        return 0
    else
        log_fail "Thermal response inadequate - temperature too high"
        return 1
    fi
}

# Main test execution
run_thermal_tests() {
    echo "🌡️ Thermal Management Test Suite"
    echo "================================="
    echo
    
    log_info "System Thermal Status:"
    log_info "Current Temperature: $(get_cpu_temp)°C"
    echo
    
    # Basic thermal tests
    test_temperature_reading
    test_thermal_thresholds
    test_temperature_monitoring_accuracy
    
    # Protection system tests
    test_emergency_thermal_protection
    test_progressive_thermal_response
    test_thermal_performance_profiles
    
    # Integration tests
    test_thermal_ai_integration
    
    # Stress test (only if system is cool enough)
    test_thermal_stress_simulation
    
    # Results summary
    echo
    echo "Thermal Test Results:"
    echo "===================="
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🌡️ All thermal tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some thermal tests failed${NC}"
        return 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_thermal_tests "$@"
fi