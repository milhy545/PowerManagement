#!/bin/bash
# 🚨 Emergency CPU Throttling - Pro přehřívající se Core 2 Quad Q9550
# Snižuje CPU load software metodou

set -e

# Konfigurace
readonly SCRIPT_NAME="emergency_cpu_throttle"
readonly LOG_FILE="/tmp/cpu_throttle.log"

log() {
    echo "$(date '+%H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

show_status() {
    echo "🔥 Emergency CPU Throttling Status"
    echo "=================================="
    
    # CPU frekvence
    echo "🖥️  CPU Info:"
    grep -E "model name|cpu MHz" /proc/cpuinfo | head -4
    
    # Load average
    echo ""
    echo "📊 System Load:"
    uptime
    
    # CPU utilization per core
    echo ""
    echo "🔄 CPU Usage per core:"
    grep "cpu[0-9]" /proc/stat | head -4 | while read line; do
        cpu=$(echo $line | awk '{print $1}')
        # Jednoduchý výpočet utilization
        echo "   $cpu: monitoring..."
    done
    
    # Processes consuming CPU
    echo ""
    echo "🔥 Top CPU processes:"
    ps aux --sort=-pcpu | head -6
    
    # Thermal info (pokud je dostupné)
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [ -n "$temp" ]; then
            temp_c=$((temp / 1000))
            echo ""
            echo "🌡️  CPU Temperature: ${temp_c}°C"
            if [ $temp_c -gt 70 ]; then
                echo "   ⚠️  VYSOKÁ TEPLOTA!"
            fi
        fi
    fi
}

throttle_cpu() {
    local level="$1"
    
    log "🚨 Starting CPU throttling level: $level"
    
    case "$level" in
        "light")
            log "💡 Light throttling - nice hodnoty"
            # Sníží prioritu všech non-critical procesů
            for pid in $(ps -eo pid,ni,cmd | awk '$2 == 0 && $3 !~ /(kernel|init|systemd)/ {print $1}'); do
                renice +5 $pid 2>/dev/null || true
            done
            ;;
        "medium")  
            log "🛑 Medium throttling - cpulimit"
            # Pokud je cpulimit dostupný
            if command -v cpulimit >/dev/null; then
                # Limit heavy processes na 50% CPU
                for pid in $(ps aux --sort=-pcpu | head -5 | tail -4 | awk '{print $2}'); do
                    cpulimit -p $pid -l 50 &
                done
            else
                log "⚠️  cpulimit není dostupný, používám nice"
                for pid in $(ps aux --sort=-pcpu | head -5 | tail -4 | awk '{print $2}'); do
                    renice +10 $pid 2>/dev/null || true
                done
            fi
            ;;
        "heavy")
            log "🔥 Heavy throttling - agresivní omezení"
            # Zastaví non-essential služby
            pkill -STOP chrome 2>/dev/null || true
            pkill -STOP firefox 2>/dev/null || true
            pkill -STOP docker 2>/dev/null || true
            
            # Sníží prioritu všech procesů
            for pid in $(ps -eo pid | tail -n +2); do
                renice +15 $pid 2>/dev/null || true
            done
            ;;
        "emergency")
            log "🚨 EMERGENCY throttling - drastické opatření"
            # Zastaví všechny non-critical procesy
            pkill -STOP ollama 2>/dev/null || true
            pkill -STOP python 2>/dev/null || true
            pkill -STOP node 2>/dev/null || true
            
            # Vypne turbo boost (pokud podporováno)
            echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
            
            log "🚨 Emergency throttling aktivní - system load by měl klesnout"
            ;;
    esac
}

restore_cpu() {
    log "♻️  Restoring CPU to normal"
    
    # Zabiří cpulimit procesy
    pkill cpulimit 2>/dev/null || true
    
    # Obnoví zastavené procesy
    pkill -CONT ollama 2>/dev/null || true
    pkill -CONT python 2>/dev/null || true
    pkill -CONT node 2>/dev/null || true
    pkill -CONT chrome 2>/dev/null || true
    pkill -CONT firefox 2>/dev/null || true
    pkill -CONT docker 2>/dev/null || true
    
    # Obnoví normální prioritu (nemůžeme bez sudo)
    log "ℹ️  Pro úplné obnovení priority procesů restartuj systém"
    
    log "✅ CPU throttling odstraněn"
}

monitor_temperature() {
    local max_temp="${1:-75}"  # Default 75°C
    
    log "🌡️  Starting temperature monitoring (max: ${max_temp}°C)"
    
    while true; do
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
            if [ -n "$temp" ]; then
                temp_c=$((temp / 1000))
                
                if [ $temp_c -gt $max_temp ]; then
                    log "🚨 CRITICAL TEMPERATURE: ${temp_c}°C - aktivuji emergency throttling"
                    throttle_cpu "emergency"
                    sleep 30
                elif [ $temp_c -gt $((max_temp - 10)) ]; then
                    log "⚠️  High temperature: ${temp_c}°C - aktivuji medium throttling"
                    throttle_cpu "medium"
                    sleep 20
                else
                    log "✅ Temperature OK: ${temp_c}°C"
                fi
            fi
        else
            # Fallback - monitor load average
            load=$(uptime | awk -F 'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
            load_int=$(echo "$load" | cut -d. -f1)
            
            if [ "$load_int" -gt 3 ]; then
                log "🚨 High CPU load: $load - aktivuji throttling"
                throttle_cpu "light"
            fi
        fi
        
        sleep 10
    done
}

# Main
case "${1:-status}" in
    "status")
        show_status
        ;;
    "light"|"medium"|"heavy"|"emergency")
        throttle_cpu "$1"
        ;;
    "restore")
        restore_cpu
        ;;
    "monitor")
        monitor_temperature "${2:-75}"
        ;;
    "help")
        echo "🚨 Emergency CPU Throttling for overheating Core 2 Quad"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  status     - Show current CPU status"
        echo "  light      - Light throttling (nice values)"
        echo "  medium     - Medium throttling (cpulimit 50%)"
        echo "  heavy      - Heavy throttling (stop non-essential)"
        echo "  emergency  - Emergency throttling (aggressive)"
        echo "  restore    - Restore normal CPU operation"
        echo "  monitor    - Auto-throttle based on temperature"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 medium"
        echo "  $0 monitor 70    # throttle at 70°C"
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Use '$0 help' for usage info"
        exit 1
        ;;
esac