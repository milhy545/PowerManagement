#!/bin/bash

#==============================================================================
# Unified Monitoring Dashboard
# Combines PowerManagement, claude-tools-monitor, and MyMenu
# Displays comprehensive system state in dmenu-compatible format
#==============================================================================

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect installation directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWER_MGMT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_MONITOR_DIR="${CLAUDE_MONITOR_DIR:-/home/user/claude-tools-monitor}"

# Python path setup
export PYTHONPATH="$POWER_MGMT_DIR/src:${PYTHONPATH:-}"

#==============================================================================
# Data Collection Functions
#==============================================================================

get_power_metrics() {
    # Get PowerManagement metrics
    local metrics_json

    if ! metrics_json=$(python3 - <<'EOF'
import sys
sys.path.insert(0, "/home/user/PowerManagement/src")

try:
    from sensors.gpu_monitor import UniversalGPUMonitor
    from sensors.universal_sensor_detector import UniversalSensorDetector, SensorType
    import json

    detector = UniversalSensorDetector()
    gpu_monitor = UniversalGPUMonitor()

    # Get CPU temp
    cpu_temp = None
    temp_sensors = detector.get_temperature_sensors()
    for sensor in temp_sensors:
        if any(x in sensor.chip.lower() for x in ['coretemp', 'k10temp', 'cpu']):
            if 'package' in sensor.label.lower() or 'tctl' in sensor.label.lower():
                cpu_temp = sensor.value
                break

    # Get GPU metrics
    gpu_temp = None
    gpu_power = None
    gpu_metrics_list = gpu_monitor.get_all_metrics()
    if gpu_metrics_list:
        gpu_metrics = gpu_metrics_list[0]
        gpu_temp = gpu_metrics.temperature
        gpu_power = gpu_metrics.power_usage

    # Get fan speeds
    cpu_fan_rpm = None
    fan_sensors = detector.get_fan_sensors()
    for sensor in fan_sensors:
        if 'cpu' in sensor.label.lower() or 'fan1' in sensor.label.lower():
            cpu_fan_rpm = int(sensor.value) if sensor.value else None
            break

    # Get CPU power
    cpu_power = None
    power_sensors = detector.get_sensors_by_type(SensorType.POWER)
    for sensor in power_sensors:
        if 'package' in sensor.label.lower() or 'cpu' in sensor.label.lower():
            cpu_power = sensor.value
            break

    result = {
        'cpu_temp': cpu_temp,
        'gpu_temp': gpu_temp,
        'cpu_fan_rpm': cpu_fan_rpm,
        'gpu_power': gpu_power,
        'cpu_power': cpu_power,
        'available': True
    }

    print(json.dumps(result))

except Exception as e:
    print(json.dumps({'available': False, 'error': str(e)}))
EOF
2>/dev/null); then
        echo '{"available": false}'
        return
    fi

    echo "$metrics_json"
}

get_claude_monitor_status() {
    # Get claude-tools-monitor status

    if [ ! -d "$CLAUDE_MONITOR_DIR" ]; then
        echo '{"available": false}'
        return
    fi

    # Check if monitoring service is running
    local running=false
    if pgrep -f "claude.*monitor" >/dev/null 2>&1; then
        running=true
    fi

    # Check recent activity
    local activity="idle"
    if [ -f "/tmp/claude_activity.log" ]; then
        local last_activity=$(tail -1 /tmp/claude_activity.log 2>/dev/null)
        if [ -n "$last_activity" ]; then
            activity="active"
        fi
    fi

    echo "{\"available\": true, \"running\": $running, \"activity\": \"$activity\"}"
}

get_current_power_profile() {
    # Get current power profile

    # Check cpufreq governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        case "$governor" in
            performance) echo "🔥 Performance" ;;
            powersave) echo "🔋 Power Save" ;;
            schedutil|ondemand) echo "⚖️ Balanced" ;;
            *) echo "❓ $governor" ;;
        esac
    else
        echo "❓ Unknown"
    fi
}

get_thermal_status() {
    # Get thermal status with color coding
    local cpu_temp="$1"

    if [ -z "$cpu_temp" ] || [ "$cpu_temp" = "null" ] || [ "$cpu_temp" = "None" ] || [ "$cpu_temp" = "N/A" ]; then
        echo "❓ N/A"
        return
    fi

    # Compare temps (bash integer comparison)
    local temp_int=${cpu_temp%.*}

    # Check if temp_int is actually a number
    if ! [[ "$temp_int" =~ ^[0-9]+$ ]]; then
        echo "❓ N/A"
        return
    fi

    if [ "$temp_int" -ge 85 ]; then
        echo "🚨 CRITICAL"
    elif [ "$temp_int" -ge 75 ]; then
        echo "⚠️  WARNING"
    elif [ "$temp_int" -ge 65 ]; then
        echo "⚡ ELEVATED"
    else
        echo "✅ GOOD"
    fi
}

#==============================================================================
# Display Functions
#==============================================================================

show_dashboard_menu() {
    # Show main dashboard menu

    cat <<MENU
📊 View Full Status
🔄 Refresh Dashboard
---
🌡️ Temperature Details
💨 Fan Control
🎮 GPU Details
⚡ Power Profiles
---
📈 Start Monitoring Service
🛑 Stop Monitoring Service
---
⚙️ Settings
MENU
}

show_full_status() {
    # Display comprehensive status

    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  🎯 Unified System Dashboard${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    # Get all metrics
    local power_metrics=$(get_power_metrics)
    local claude_status=$(get_claude_monitor_status)
    local power_profile=$(get_current_power_profile)

    # Parse power metrics
    local cpu_temp=$(echo "$power_metrics" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('cpu_temp', 'N/A'))")
    local gpu_temp=$(echo "$power_metrics" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('gpu_temp', 'N/A'))")
    local cpu_fan=$(echo "$power_metrics" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('cpu_fan_rpm', 'N/A'))")
    local gpu_power=$(echo "$power_metrics" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('gpu_power', 'N/A'))")
    local cpu_power=$(echo "$power_metrics" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('cpu_power', 'N/A'))")

    # System Overview
    echo -e "${GREEN}🖥️  SYSTEM OVERVIEW${NC}"
    echo -e "  Power Profile: $power_profile"
    echo -e "  Thermal Status: $(get_thermal_status "$cpu_temp")"
    echo ""

    # Temperature Monitoring
    echo -e "${GREEN}🌡️  TEMPERATURE${NC}"
    if [ "$cpu_temp" != "N/A" ] && [ "$cpu_temp" != "null" ]; then
        echo -e "  CPU: ${YELLOW}${cpu_temp}°C${NC}"
    else
        echo -e "  CPU: ${RED}N/A${NC}"
    fi

    if [ "$gpu_temp" != "N/A" ] && [ "$gpu_temp" != "null" ]; then
        echo -e "  GPU: ${YELLOW}${gpu_temp}°C${NC}"
    else
        echo -e "  GPU: ${RED}N/A${NC}"
    fi
    echo ""

    # Fan Monitoring
    echo -e "${GREEN}💨 FANS${NC}"
    if [ "$cpu_fan" != "N/A" ] && [ "$cpu_fan" != "null" ]; then
        echo -e "  CPU Fan: ${YELLOW}${cpu_fan} RPM${NC}"
    else
        echo -e "  CPU Fan: ${RED}N/A${NC}"
    fi
    echo ""

    # Power Monitoring
    echo -e "${GREEN}⚡ POWER${NC}"
    if [ "$cpu_power" != "N/A" ] && [ "$cpu_power" != "null" ]; then
        echo -e "  CPU: ${YELLOW}${cpu_power}W${NC}"
    else
        echo -e "  CPU: ${RED}N/A${NC}"
    fi

    if [ "$gpu_power" != "N/A" ] && [ "$gpu_power" != "null" ]; then
        echo -e "  GPU: ${YELLOW}${gpu_power}W${NC}"
    else
        echo -e "  GPU: ${RED}N/A${NC}"
    fi
    echo ""

    # Claude Monitor Status
    echo -e "${GREEN}🤖 CLAUDE MONITOR${NC}"
    local claude_available=$(echo "$claude_status" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('available', False))")

    if [ "$claude_available" = "True" ]; then
        local claude_running=$(echo "$claude_status" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('running', False))")
        local claude_activity=$(echo "$claude_status" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('activity', 'idle'))")

        if [ "$claude_running" = "True" ]; then
            echo -e "  Status: ${GREEN}Running${NC}"
        else
            echo -e "  Status: ${RED}Stopped${NC}"
        fi
        echo -e "  Activity: $claude_activity"
    else
        echo -e "  Status: ${RED}Not Available${NC}"
    fi
    echo ""

    echo -e "${BLUE}============================================${NC}"
}

show_temperature_details() {
    # Show detailed temperature information

    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  🌡️  Temperature Details${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    # Run sensor detector
    if command -v python3 >/dev/null 2>&1; then
        python3 "$POWER_MGMT_DIR/src/sensors/universal_sensor_detector.py" 2>/dev/null | head -40
    else
        echo -e "${RED}Python3 not available${NC}"
    fi
}

show_gpu_details() {
    # Show detailed GPU information

    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  🎮 GPU Details${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    # Run GPU monitor
    if command -v python3 >/dev/null 2>&1; then
        python3 "$POWER_MGMT_DIR/src/sensors/gpu_monitor.py" 2>/dev/null
    else
        echo -e "${RED}Python3 not available${NC}"
    fi
}

start_monitoring_service() {
    # Start the monitoring service

    echo -e "${GREEN}Starting monitoring service...${NC}"

    # Check if already running
    if pgrep -f "monitoring_service.py" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Monitoring service already running${NC}"
        return
    fi

    # Start service in background
    nohup python3 "$POWER_MGMT_DIR/src/services/monitoring_service.py" \
        --interval 5 \
        --log-dir /tmp \
        >/tmp/monitoring_service.log 2>&1 &

    echo -e "${GREEN}✅ Monitoring service started${NC}"
    echo -e "   Log: /tmp/power_monitoring.log"
    echo -e "   JSON: /tmp/power_monitoring.json"
}

stop_monitoring_service() {
    # Stop the monitoring service

    echo -e "${YELLOW}Stopping monitoring service...${NC}"

    if ! pgrep -f "monitoring_service.py" >/dev/null 2>&1; then
        echo -e "${RED}❌ Monitoring service not running${NC}"
        return
    fi

    pkill -f "monitoring_service.py"
    echo -e "${GREEN}✅ Monitoring service stopped${NC}"
}

#==============================================================================
# Menu Handler
#==============================================================================

handle_menu_choice() {
    local choice="$1"

    case "$choice" in
        "📊 View Full Status")
            show_full_status
            read -p "Press Enter to continue..."
            ;;
        "🔄 Refresh Dashboard")
            exec "$0"
            ;;
        "🌡️ Temperature Details")
            show_temperature_details
            read -p "Press Enter to continue..."
            ;;
        "💨 Fan Control")
            bash "$POWER_MGMT_DIR/integrations/mymenu_integration.sh" "💨 Fan Control"
            ;;
        "🎮 GPU Details")
            show_gpu_details
            read -p "Press Enter to continue..."
            ;;
        "⚡ Power Profiles")
            bash "$POWER_MGMT_DIR/integrations/mymenu_integration.sh" "⚡ Power Profiles"
            ;;
        "📈 Start Monitoring Service")
            start_monitoring_service
            read -p "Press Enter to continue..."
            ;;
        "🛑 Stop Monitoring Service")
            stop_monitoring_service
            read -p "Press Enter to continue..."
            ;;
        "⚙️ Settings")
            echo "Settings menu - Coming soon"
            read -p "Press Enter to continue..."
            ;;
        *)
            echo "Unknown option: $choice"
            ;;
    esac
}

#==============================================================================
# Main Entry Point
#==============================================================================

main() {
    # Check if running in dmenu mode
    if [ "${1:-}" = "--dmenu" ]; then
        show_dashboard_menu
        exit 0
    fi

    # Check if choice provided
    if [ $# -gt 0 ]; then
        handle_menu_choice "$*"
        exit 0
    fi

    # Interactive mode - show status and menu
    while true; do
        clear
        show_full_status
        echo ""
        echo "Select option:"

        # Show menu and get choice
        local choice
        choice=$(show_dashboard_menu | nl -w2 -s'. ' | fzf --prompt="Select: " | sed 's/^[[:space:]]*[0-9]*\.[[:space:]]*//')

        if [ -z "$choice" ]; then
            break
        fi

        handle_menu_choice "$choice"
    done
}

# Run main function
main "$@"
