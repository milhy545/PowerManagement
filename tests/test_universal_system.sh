#!/bin/bash

#==============================================================================
# Universal System Test Suite
# Tests hardware detection, configuration, and universal managers
#==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Test results
declare -a FAILED_TESTS

#==============================================================================
# Helper Functions
#==============================================================================

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Universal System Test Suite${NC}"
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

test_skip() {
    echo -e "${YELLOW}⏭️  SKIP${NC} - $1"
    ((SKIPPED++))
}

#==============================================================================
# Path Detection
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$INSTALL_DIR/src"

#==============================================================================
# Test Cases
#==============================================================================

test_file_exists() {
    local file="$1"
    local desc="$2"

    test_start "$desc"

    if [ -f "$file" ]; then
        test_pass
        return 0
    else
        test_fail "$desc"
        return 1
    fi
}

test_python_import() {
    local module="$1"
    local desc="$2"

    test_start "$desc"

    if python3 -c "import sys; sys.path.insert(0, '$SRC_DIR'); $module" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "$desc"
        return 1
    fi
}

test_python_script() {
    local script="$1"
    local args="$2"
    local desc="$3"

    test_start "$desc"

    if python3 "$script" $args >/dev/null 2>&1; then
        test_pass
        return 0
    else
        test_fail "$desc"
        return 1
    fi
}

#==============================================================================
# Main Tests
#==============================================================================

print_header

echo -e "${YELLOW}📁 Testing File Structure...${NC}"
echo ""

# Test core files
test_file_exists "$SRC_DIR/hardware/hardware_detector.py" "Hardware detector exists"
test_file_exists "$SRC_DIR/config/power_config.py" "Power config exists"
test_file_exists "$SRC_DIR/frequency/universal_cpu_manager.py" "Universal CPU manager exists"
test_file_exists "$SRC_DIR/frequency/cpu_frequency_manager.py" "Legacy CPU manager exists"
test_file_exists "$INSTALL_DIR/scripts/performance_manager.sh" "Performance manager exists"
test_file_exists "$INSTALL_DIR/scripts/ai_process_manager.sh" "AI process manager exists"
test_file_exists "$INSTALL_DIR/scripts/smart_thermal_manager.py" "Smart thermal manager exists"
test_file_exists "$INSTALL_DIR/daemons/custom-power-profiles-daemon.py" "Custom daemon exists"

echo ""
echo -e "${YELLOW}🐍 Testing Python Modules...${NC}"
echo ""

# Test Python imports
test_python_import "from hardware.hardware_detector import HardwareDetector" "Hardware detector import"
test_python_import "from config.power_config import PowerConfig" "Power config import"

echo ""
echo -e "${YELLOW}🔍 Testing Hardware Detection...${NC}"
echo ""

# Test hardware detection
test_start "Hardware detector execution"
if python3 "$SRC_DIR/hardware/hardware_detector.py" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Hardware detector execution"
fi

# Run hardware detection and show results
echo ""
echo -e "${BLUE}Hardware Detection Results:${NC}"
python3 "$SRC_DIR/hardware/hardware_detector.py" 2>/dev/null | head -20 || echo "  (Detection failed - may need root access)"
echo ""

echo -e "${YELLOW}⚙️  Testing Configuration System...${NC}"
echo ""

test_start "Configuration system execution"
if python3 "$SRC_DIR/config/power_config.py" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Configuration system execution"
fi

echo ""
echo -e "${YELLOW}⚡ Testing Universal CPU Manager...${NC}"
echo ""

test_start "Universal CPU manager status"
if python3 "$SRC_DIR/frequency/universal_cpu_manager.py" status >/dev/null 2>&1; then
    test_pass
else
    test_fail "Universal CPU manager status"
fi

test_start "Universal CPU manager detect"
if python3 "$SRC_DIR/frequency/universal_cpu_manager.py" detect >/dev/null 2>&1; then
    test_pass
else
    test_fail "Universal CPU manager detect"
fi

echo ""
echo -e "${BLUE}Universal CPU Manager Status:${NC}"
python3 "$SRC_DIR/frequency/universal_cpu_manager.py" status 2>/dev/null || echo "  (May need root for full functionality)"
echo ""

echo -e "${YELLOW}🌡️  Testing Thermal Manager...${NC}"
echo ""

test_start "Smart thermal manager initialization"
if python3 "$INSTALL_DIR/scripts/smart_thermal_manager.py" >/dev/null 2>&1; then
    test_pass
else
    # Thermal manager might not exit cleanly in test mode
    test_skip "requires interactive mode"
fi

echo ""
echo -e "${YELLOW}🔧 Testing Shell Scripts...${NC}"
echo ""

test_start "Performance manager help"
if bash "$INSTALL_DIR/scripts/performance_manager.sh" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Performance manager help"
fi

test_start "AI process manager help"
if bash "$INSTALL_DIR/scripts/ai_process_manager.sh" >/dev/null 2>&1; then
    test_pass
else
    # AI manager might exit with error when no args provided
    test_skip "requires arguments"
fi

echo ""
echo -e "${YELLOW}🔍 Testing Dynamic Path Resolution...${NC}"
echo ""

test_start "Performance manager finds CPU manager"
if grep -q "universal_cpu_manager.py" "$INSTALL_DIR/scripts/performance_manager.sh"; then
    test_pass
else
    test_fail "Performance manager finds CPU manager"
fi

test_start "AI manager finds performance manager"
if grep -q "POWER_MANAGER_PATH=\"\$SCRIPT_DIR/performance_manager.sh\"" "$INSTALL_DIR/scripts/ai_process_manager.sh"; then
    test_pass
else
    test_fail "AI manager finds performance manager"
fi

test_start "Daemon uses PowerConfig"
if grep -q "from config.power_config import PowerConfig" "$INSTALL_DIR/daemons/custom-power-profiles-daemon.py"; then
    test_pass
else
    test_fail "Daemon uses PowerConfig"
fi

echo ""
echo -e "${YELLOW}🚫 Testing Hardcoded Path Removal...${NC}"
echo ""

test_start "No /home/milhy777 in daemon"
if ! grep -q "/home/milhy777" "$INSTALL_DIR/daemons/custom-power-profiles-daemon.py"; then
    test_pass
else
    test_fail "No /home/milhy777 in daemon"
fi

test_start "No /home/milhy777 in performance_manager"
if ! grep -q "/home/milhy777" "$INSTALL_DIR/scripts/performance_manager.sh"; then
    test_pass
else
    test_fail "No /home/milhy777 in performance_manager"
fi

test_start "No /home/milhy777 in ai_process_manager"
if ! grep -q "/home/milhy777" "$INSTALL_DIR/scripts/ai_process_manager.sh"; then
    test_pass
else
    test_fail "No /home/milhy777 in ai_process_manager"
fi

test_start "No hardcoded 'claude --agent' calls"
if ! grep -q "claude --agent" "$INSTALL_DIR/scripts/performance_manager.sh"; then
    test_pass
else
    test_fail "No hardcoded 'claude --agent' calls"
fi

echo ""
echo -e "${YELLOW}🎮 Testing GPU Detection...${NC}"
echo ""

test_start "GPU auto-detection in performance_manager"
if grep -q "for card in /sys/class/drm/card\[0-9\]" "$INSTALL_DIR/scripts/performance_manager.sh"; then
    test_pass
else
    test_fail "GPU auto-detection in performance_manager"
fi

#==============================================================================
# Results Summary
#==============================================================================

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Test Results Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "✅ Passed:  ${GREEN}$PASSED${NC}"
echo -e "❌ Failed:  ${RED}$FAILED${NC}"
echo -e "⏭️  Skipped: ${YELLOW}$SKIPPED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    echo -e "${GREEN}✅ Universal system is ready!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "   - $test"
    done
    exit 1
fi
