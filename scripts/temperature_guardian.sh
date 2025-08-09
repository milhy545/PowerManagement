#!/bin/bash
# 🌡️ Temperature Guardian - Proactive protection pro Core 2 Quad Q9550
# Monitoruje teplotu každé 2 sekundy a aplikuje progresivní throttling

set -e

readonly MAX_TEMP=70      # 70°C = aggressive throttling  
readonly CRITICAL_TEMP=75 # 75°C = emergency stop
readonly LOG_FILE="/tmp/temp_guardian.log"

log() {
    echo "$(date '+%H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

get_temperature() {
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [ -n "$temp" ]; then
            echo $((temp / 1000))
            return
        fi
    fi
    echo "0"  # Fallback
}

kill_heavy_processes() {
    log "🚨 EMERGENCY: Killing heavy processes"
    
    # Kill Docker builds
    pkill -f "docker" 2>/dev/null || true
    pkill -f "ollama" 2>/dev/null || true
    pkill -f "python.*ollama" 2>/dev/null || true
    
    # Stop všechny AI procesy
    pkill -f "claude" 2>/dev/null || true
    pkill -f "npm" 2>/dev/null || true
    
    # Extreme: Zastaví i některé desktop procesy
    pkill -STOP plasma-systemmonitor 2>/dev/null || true
    
    log "🛑 Heavy processes terminated"
}

progressive_throttling() {
    local temp=$1
    
    if [ $temp -ge $CRITICAL_TEMP ]; then
        log "🚨 CRITICAL TEMP: ${temp}°C - EMERGENCY SHUTDOWN"
        kill_heavy_processes
        return
    fi
    
    if [ $temp -ge $((CRITICAL_TEMP - 3)) ]; then  # 72°C+
        log "🔥 VERY HIGH: ${temp}°C - Heavy throttling"
        # Kill heavy processes
        pkill -f "docker.*build" 2>/dev/null || true
        pkill -f "ollama.*serve" 2>/dev/null || true
        
        # Max nice všechny procesy
        for pid in $(ps -eo pid | tail -n +2); do
            renice +19 $pid 2>/dev/null || true
        done
        
    elif [ $temp -ge $MAX_TEMP ]; then  # 70°C+
        log "⚠️  HIGH: ${temp}°C - Medium throttling"
        # Sníž prioritu heavy procesů
        for pid in $(ps aux --sort=-pcpu | head -10 | tail -9 | awk '{print $2}'); do
            renice +15 $pid 2>/dev/null || true
        done
        
    elif [ $temp -ge $((MAX_TEMP - 5)) ]; then  # 65°C+
        log "💡 WARM: ${temp}°C - Light throttling"
        # Základní throttling
        for pid in $(ps aux --sort=-pcpu | head -6 | tail -5 | awk '{print $2}'); do
            renice +10 $pid 2>/dev/null || true
        done
    else
        # Teplota OK
        if [ $(($(date +%s) % 10)) -eq 0 ]; then  # Každých 10 sekund
            log "✅ OK: ${temp}°C"
        fi
    fi
}

monitor_continuously() {
    log "🌡️  Starting continuous temperature monitoring"
    log "🎯 Limits: ${MAX_TEMP}°C throttling, ${CRITICAL_TEMP}°C emergency"
    
    while true; do
        temp=$(get_temperature)
        
        if [ $temp -gt 0 ]; then
            progressive_throttling $temp
        fi
        
        sleep 2  # Check každé 2 sekundy
    done
}

show_status() {
    temp=$(get_temperature)
    echo "🌡️  Temperature Guardian Status"
    echo "=============================="
    echo "Current temp: ${temp}°C"
    echo "Max allowed: ${MAX_TEMP}°C"
    echo "Critical: ${CRITICAL_TEMP}°C"
    echo ""
    
    if [ $temp -ge $CRITICAL_TEMP ]; then
        echo "🚨 STATUS: CRITICAL - Emergency active"
    elif [ $temp -ge $MAX_TEMP ]; then
        echo "⚠️  STATUS: HIGH - Throttling active"  
    elif [ $temp -ge $((MAX_TEMP - 5)) ]; then
        echo "💡 STATUS: WARM - Light protection"
    else
        echo "✅ STATUS: OK - Normal operation"
    fi
    
    echo ""
    echo "Recent log:"
    tail -5 "$LOG_FILE" 2>/dev/null || echo "No log yet"
}

# Main
case "${1:-monitor}" in
    "monitor")
        monitor_continuously
        ;;
    "status")
        show_status
        ;;
    "kill")
        kill_heavy_processes
        ;;
    "help")
        echo "🌡️  Temperature Guardian for Core 2 Quad Q9550"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  monitor  - Start continuous monitoring (default)"
        echo "  status   - Show current temperature status" 
        echo "  kill     - Emergency kill heavy processes"
        echo ""
        echo "🎯 Auto-throttling:"
        echo "  65°C - Light throttling"
        echo "  70°C - Medium throttling" 
        echo "  72°C - Heavy throttling"
        echo "  75°C - Emergency shutdown"
        ;;
    *)
        echo "❌ Unknown command: $1"
        exit 1
        ;;
esac