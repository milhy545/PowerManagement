#!/bin/bash

#==============================================================================
# PowerManagement Integration for MyMenu
# Provides dmenu-compatible interface for power management
#==============================================================================

set -euo pipefail

# Detect PowerManagement installation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWER_MGMT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$POWER_MGMT_DIR/src"

export PYTHONPATH="$SRC_DIR:${PYTHONPATH:-}"

#==============================================================================
# Functions
#==============================================================================

show_power_menu() {
    echo "🔥 Performance Mode"
    echo "⚖️ Balanced Mode"
    echo "🔋 Power Save Mode"
    echo "🚨 Emergency Mode"
    echo "---"
    echo "📊 Show Current Status"
    echo "🎮 Show GPU Metrics"
    echo "🌡️ Show All Sensors"
    echo "💨 Show Fan Status"
    echo "---"
    echo "🔧 Fan Control Menu"
    echo "📈 Start Monitoring Service"
    echo "📖 Show Documentation"
}

show_fan_menu() {
    echo "💨 Fan Status"
    echo "---"
    echo "🌀 Set CPU Fan 30% (Silent)"
    echo "🌀 Set CPU Fan 50% (Normal)"
    echo "🌀 Set CPU Fan 75% (High)"
    echo "🌀 Set CPU Fan 100% (Max)"
    echo "---"
    echo "🔄 Set Auto Mode"
}

gpu_metrics() {
    python3 "$SRC_DIR/sensors/gpu_monitor.py" | \
        zenity --text-info --title="GPU Metrics" --width=800 --height=600 || \
        xterm -e "python3 $SRC_DIR/sensors/gpu_monitor.py; read -p 'Press Enter to close...'"
}

all_sensors() {
    python3 "$SRC_DIR/sensors/universal_sensor_detector.py" | \
        zenity --text-info --title="All Sensors" --width=900 --height=700 || \
        xterm -e "python3 $SRC_DIR/sensors/universal_sensor_detector.py; read -p 'Press Enter to close...'"
}

fan_status() {
    python3 "$SRC_DIR/sensors/fan_controller.py" status | \
        zenity --text-info --title="Fan Status" --width=800 --height=500 || \
        xterm -e "python3 $SRC_DIR/sensors/fan_controller.py status; read -p 'Press Enter to close...'"
}

current_status() {
    "$POWER_MGMT_DIR/scripts/performance_manager.sh" status | \
        zenity --text-info --title="Power Management Status" --width=800 --height=600 || \
        xterm -e "$POWER_MGMT_DIR/scripts/performance_manager.sh status; read -p 'Press Enter to close...'"
}

start_monitoring() {
    # Start in terminal
    xterm -T "Power Monitoring Service" -e \
        "python3 $SRC_DIR/services/monitoring_service.py" &
}

show_docs() {
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$POWER_MGMT_DIR/docs/SENSOR_MONITORING.md"
    else
        xterm -e "less $POWER_MGMT_DIR/docs/SENSOR_MONITORING.md"
    fi
}

#==============================================================================
# Main Logic
#==============================================================================

case "${1:-menu}" in
    "menu")
        # Show main power menu
        show_power_menu
        ;;

    "fan-menu")
        # Show fan control menu
        show_fan_menu
        ;;

    "performance")
        "$POWER_MGMT_DIR/scripts/performance_manager.sh" performance
        notify-send "Power Management" "Performance mode activated" -i dialog-information
        ;;

    "balanced")
        "$POWER_MGMT_DIR/scripts/performance_manager.sh" balanced
        notify-send "Power Management" "Balanced mode activated" -i dialog-information
        ;;

    "powersave")
        "$POWER_MGMT_DIR/scripts/performance_manager.sh" powersave
        notify-send "Power Management" "Power save mode activated" -i dialog-information
        ;;

    "emergency")
        "$POWER_MGMT_DIR/scripts/performance_manager.sh" emergency
        notify-send "Power Management" "Emergency mode activated" -u critical
        ;;

    "status")
        current_status
        ;;

    "gpu")
        gpu_metrics
        ;;

    "sensors")
        all_sensors
        ;;

    "fans")
        fan_status
        ;;

    "fan-30")
        sudo python3 "$SRC_DIR/sensors/fan_controller.py" set 0 30
        notify-send "Fan Control" "CPU fan set to 30%" -i dialog-information
        ;;

    "fan-50")
        sudo python3 "$SRC_DIR/sensors/fan_controller.py" set 0 50
        notify-send "Fan Control" "CPU fan set to 50%" -i dialog-information
        ;;

    "fan-75")
        sudo python3 "$SRC_DIR/sensors/fan_controller.py" set 0 75
        notify-send "Fan Control" "CPU fan set to 75%" -i dialog-information
        ;;

    "fan-100")
        sudo python3 "$SRC_DIR/sensors/fan_controller.py" set 0 100
        notify-send "Fan Control" "CPU fan set to 100%" -u critical
        ;;

    "fan-auto")
        sudo python3 "$SRC_DIR/sensors/fan_controller.py" auto 0
        notify-send "Fan Control" "Auto mode enabled" -i dialog-information
        ;;

    "monitoring")
        start_monitoring
        notify-send "Power Management" "Monitoring service started" -i dialog-information
        ;;

    "docs")
        show_docs
        ;;

    *)
        echo "Unknown command: $1"
        exit 1
        ;;
esac
