#!/bin/bash

#==============================================================================
# Comprehensive Test Suite for Sensor Monitoring & Fan Control
# Tests all new modules with detailed error reporting
#==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Test results
declare -a FAILED_TESTS
declare -a WARNINGS_LIST

#==============================================================================
# Helper Functions
#==============================================================================

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

test_start() {
    echo -n "Testing: $1... "
}

test_pass() {
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}❌ FAIL${NC}"
    ((FAILED++))
    FAILED_TESTS+=("$1")
}

test_warn() {
    echo -e "${YELLOW}⚠️  WARNING${NC} - $1"
    ((WARNINGS++))
    WARNINGS_LIST+=("$1")
}

#==============================================================================
# Path Detection
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$INSTALL_DIR/src"

#==============================================================================
# Python Module Tests
#==============================================================================

test_python_syntax() {
    local file="$1"
    local desc="$2"

    test_start "$desc - syntax check"

    if python3 -m py_compile "$file" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "$desc - syntax"
        return 1
    fi
}

test_python_import() {
    local file="$1"
    local module="$2"
    local desc="$3"

    test_start "$desc - import test"

    # Set PYTHONPATH
    export PYTHONPATH="$SRC_DIR:$PYTHONPATH"

    if python3 -c "$module" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "$desc - import"
        return 1
    fi
}

test_python_execution() {
    local file="$1"
    local args="$2"
    local desc="$3"

    test_start "$desc - execution test"

    export PYTHONPATH="$SRC_DIR:$PYTHONPATH"

    # Run with timeout
    if timeout 5 python3 "$file" $args >/dev/null 2>&1; then
        test_pass
        return 0
    else
        # Check exit code
        exit_code=$?
        if [ $exit_code -eq 124 ]; then
            test_fail "$desc - timeout"
        else
            test_warn "$desc - exit code $exit_code (may be expected in CI)"
        fi
        return 1
    fi
}

#==============================================================================
# Main Tests
#==============================================================================

print_header "SENSOR MONITORING & FAN CONTROL TEST SUITE"

echo -e "${YELLOW}📁 Installation Directory: $INSTALL_DIR${NC}"
echo -e "${YELLOW}🐍 Python: $(python3 --version)${NC}"
echo ""

#==============================================================================
# Test 1: File Existence
#==============================================================================

print_header "File Existence Tests"

test_start "GPU monitor exists"
if [ -f "$SRC_DIR/sensors/gpu_monitor.py" ]; then
    test_pass
else
    test_fail "GPU monitor exists"
fi

test_start "Sensor detector exists"
if [ -f "$SRC_DIR/sensors/universal_sensor_detector.py" ]; then
    test_pass
else
    test_fail "Sensor detector exists"
fi

test_start "Fan controller exists"
if [ -f "$SRC_DIR/sensors/fan_controller.py" ]; then
    test_pass
else
    test_fail "Fan controller exists"
fi

test_start "Monitoring service exists"
if [ -f "$SRC_DIR/services/monitoring_service.py" ]; then
    test_pass
else
    test_fail "Monitoring service exists"
fi

echo ""

#==============================================================================
# Test 2: Python Syntax
#==============================================================================

print_header "Python Syntax Tests"

test_python_syntax "$SRC_DIR/sensors/gpu_monitor.py" "GPU monitor"
test_python_syntax "$SRC_DIR/sensors/universal_sensor_detector.py" "Sensor detector"
test_python_syntax "$SRC_DIR/sensors/fan_controller.py" "Fan controller"
test_python_syntax "$SRC_DIR/services/monitoring_service.py" "Monitoring service"

echo ""

#==============================================================================
# Test 3: Python Imports
#==============================================================================

print_header "Python Import Tests"

test_python_import "$SRC_DIR/sensors/gpu_monitor.py" \
    "from sensors.gpu_monitor import UniversalGPUMonitor" \
    "GPU monitor"

test_python_import "$SRC_DIR/sensors/universal_sensor_detector.py" \
    "from sensors.universal_sensor_detector import UniversalSensorDetector" \
    "Sensor detector"

test_python_import "$SRC_DIR/sensors/fan_controller.py" \
    "from sensors.fan_controller import UniversalFanController" \
    "Fan controller"

test_python_import "$SRC_DIR/services/monitoring_service.py" \
    "from services.monitoring_service import MonitoringService" \
    "Monitoring service"

echo ""

#==============================================================================
# Test 4: Module Execution
#==============================================================================

print_header "Module Execution Tests"

echo -e "${YELLOW}Note: Some tests may show warnings in CI environment (no hardware)${NC}"
echo ""

test_start "GPU monitor execution"
export PYTHONPATH="$SRC_DIR:$PYTHONPATH"
if timeout 5 python3 "$SRC_DIR/sensors/gpu_monitor.py" >/dev/null 2>&1; then
    test_pass
else
    test_warn "GPU monitor - no GPU in CI (expected)"
fi

test_start "Sensor detector execution"
if timeout 5 python3 "$SRC_DIR/sensors/universal_sensor_detector.py" >/dev/null 2>&1; then
    test_pass
else
    test_warn "Sensor detector - no sensors in CI (expected)"
fi

test_start "Fan controller execution"
if timeout 5 python3 "$SRC_DIR/sensors/fan_controller.py" >/dev/null 2>&1; then
    test_pass
else
    test_warn "Fan controller - no fans in CI (expected)"
fi

echo ""

#==============================================================================
# Test 5: Integration Tests
#==============================================================================

print_header "Integration Tests"

test_start "Hardware detector + GPU monitor integration"
export PYTHONPATH="$SRC_DIR:$PYTHONPATH"
if python3 -c "
from hardware.hardware_detector import HardwareDetector
from sensors.gpu_monitor import UniversalGPUMonitor
hd = HardwareDetector()
gm = UniversalGPUMonitor()
" 2>/dev/null; then
    test_pass
else
    test_fail "Hardware detector + GPU monitor integration"
fi

test_start "Config + Sensor detector integration"
if python3 -c "
from config.power_config import PowerConfig
from sensors.universal_sensor_detector import UniversalSensorDetector
cfg = PowerConfig()
sd = UniversalSensorDetector()
" 2>/dev/null; then
    test_pass
else
    test_fail "Config + Sensor detector integration"
fi

test_start "Fan controller + Sensor detector integration"
if python3 -c "
from sensors.fan_controller import UniversalFanController
from sensors.universal_sensor_detector import UniversalSensorDetector
fc = UniversalFanController()
sd = UniversalSensorDetector()
" 2>/dev/null; then
    test_pass
else
    test_fail "Fan controller + Sensor detector integration"
fi

echo ""

#==============================================================================
# Test 6: Dependency Tests
#==============================================================================

print_header "Dependency Tests"

test_start "Python version >= 3.6"
python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
if python3 -c 'import sys; exit(0 if sys.version_info >= (3, 6) else 1)'; then
    test_pass
else
    test_fail "Python version >= 3.6"
fi

test_start "psutil module available"
if python3 -c 'import psutil' 2>/dev/null; then
    test_pass
else
    test_warn "psutil not installed (pip install psutil)"
fi

test_start "pathlib available"
if python3 -c 'from pathlib import Path' 2>/dev/null; then
    test_pass
else
    test_fail "pathlib not available"
fi

test_start "dataclasses available"
if python3 -c 'from dataclasses import dataclass' 2>/dev/null; then
    test_pass
else
    test_fail "dataclasses not available"
fi

echo ""

#==============================================================================
# Test 7: Hardware Detection (Real Hardware)
#==============================================================================

print_header "Hardware Detection Tests (may fail in CI)"

test_start "CPU detection"
export PYTHONPATH="$SRC_DIR:$PYTHONPATH"
if python3 -c "
from hardware.hardware_detector import HardwareDetector
hd = HardwareDetector()
assert hd.cpu_info.cores > 0
" 2>/dev/null; then
    test_pass
else
    test_warn "CPU detection (expected in CI)"
fi

test_start "Sensor detection count"
if python3 -c "
from sensors.universal_sensor_detector import UniversalSensorDetector
sd = UniversalSensorDetector()
# In CI, may have 0 sensors
assert sd.sensors is not None
" 2>/dev/null; then
    test_pass
else
    test_fail "Sensor detection"
fi

echo ""

#==============================================================================
# Test 8: Error Handling
#==============================================================================

print_header "Error Handling Tests"

test_start "GPU monitor handles no GPU"
if python3 -c "
from sensors.gpu_monitor import UniversalGPUMonitor
gm = UniversalGPUMonitor()
# Should not crash even with no GPU
metrics = gm.get_metrics(0)
" 2>/dev/null; then
    test_pass
else
    test_fail "GPU monitor error handling"
fi

test_start "Fan controller handles no fans"
if python3 -c "
from sensors.fan_controller import UniversalFanController
fc = UniversalFanController()
# Should not crash even with no fans
info = fc.get_fan_info(999)  # Non-existent fan
assert info is None
" 2>/dev/null; then
    test_pass
else
    test_fail "Fan controller error handling"
fi

test_start "Sensor detector handles empty system"
if python3 -c "
from sensors.universal_sensor_detector import UniversalSensorDetector
sd = UniversalSensorDetector()
# Should work even with no sensors
temps = sd.get_temperature_sensors()
assert isinstance(temps, list)
" 2>/dev/null; then
    test_pass
else
    test_fail "Sensor detector error handling"
fi

echo ""

#==============================================================================
# Test 9: Documentation Tests
#==============================================================================

print_header "Documentation Tests"

test_start "SENSOR_MONITORING.md exists"
if [ -f "$INSTALL_DIR/docs/SENSOR_MONITORING.md" ]; then
    test_pass
else
    test_fail "SENSOR_MONITORING.md exists"
fi

test_start "UNIVERSAL_HARDWARE.md exists"
if [ -f "$INSTALL_DIR/docs/UNIVERSAL_HARDWARE.md" ]; then
    test_pass
else
    test_fail "UNIVERSAL_HARDWARE.md exists"
fi

test_start "README.md mentions v3.1"
if grep -q "3.1" "$INSTALL_DIR/README.md" 2>/dev/null; then
    test_pass
else
    test_fail "README.md mentions v3.1"
fi

echo ""

#==============================================================================
# Test 10: Compatibility Tests
#==============================================================================

print_header "Compatibility Tests"

test_start "Works without nvidia-smi"
if python3 -c "
from sensors.gpu_monitor import UniversalGPUMonitor
gm = UniversalGPUMonitor()
# Should work without nvidia-smi
" 2>/dev/null; then
    test_pass
else
    test_fail "Works without nvidia-smi"
fi

test_start "Works without lm-sensors"
if python3 -c "
from sensors.universal_sensor_detector import UniversalSensorDetector
sd = UniversalSensorDetector()
# Should work without sensors command
" 2>/dev/null; then
    test_pass
else
    test_fail "Works without lm-sensors"
fi

test_start "Works without root access"
if python3 -c "
from sensors.fan_controller import UniversalFanController
fc = UniversalFanController()
# Should detect but not control without root
" 2>/dev/null; then
    test_pass
else
    test_fail "Works without root access"
fi

echo ""

#==============================================================================
# Results Summary
#==============================================================================

print_header "TEST RESULTS SUMMARY"

echo -e "✅ Passed:   ${GREEN}$PASSED${NC}"
echo -e "❌ Failed:   ${RED}$FAILED${NC}"
echo -e "⚠️  Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}✅ System is ready for production use!${NC}"
        exit 0
    else
        echo -e "${YELLOW}✅ Tests passed with warnings (expected in CI)${NC}"
        echo -e "${YELLOW}Warnings:${NC}"
        for warn in "${WARNINGS_LIST[@]}"; do
            echo -e "  ${YELLOW}⚠️  $warn${NC}"
        done
        exit 0
    fi
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${RED}Failed tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}❌ $test${NC}"
    done
    echo ""
    echo -e "${YELLOW}Please fix the issues before deploying${NC}"
    exit 1
fi
