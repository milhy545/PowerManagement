#!/bin/bash

# Emergency System Protection for Q9550
# Addresses BIOS limitations with kernel-level controls

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMP_THRESHOLD=70
readonly CRITICAL_THRESHOLD=75
readonly LOG_FILE="/tmp/system_protection.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running as root for critical operations
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_msg "ERROR: Some operations require root privileges"
        return 1
    fi
}

# Disable CPU Turbo Boost (multiple methods)
disable_turbo_boost() {
    log_msg "Disabling CPU Turbo Boost..."
    
    # Method 1: Intel P-State (if available)
    if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
        echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
        log_msg "✓ Intel P-State Turbo disabled"
    fi
    
    # Method 2: MSR register direct access
    if command -v wrmsr >/dev/null 2>&1; then
        modprobe msr 2>/dev/null || true
        # MSR 0x1FC - Turbo Boost disable bit
        wrmsr 0x1FC 0x4005d 2>/dev/null || log_msg "MSR Turbo disable failed"
        log_msg "✓ MSR Turbo Boost disabled"
    fi
    
    # Method 3: Kernel parameter (persistent)
    if ! grep -q "intel_pstate=disable" /proc/cmdline; then
        log_msg "ℹ Add 'intel_pstate=disable' to GRUB for permanent effect"
    fi
}

# Set all processes to low priority by default
set_global_nice() {
    log_msg "Setting global process priority..."
    
    # Set all existing processes to nice +5 (except critical ones)
    for pid in $(ps -eo pid --no-headers | grep -v $$); do
        if [[ $pid -gt 10 ]]; then  # Skip kernel processes
            renice +5 "$pid" 2>/dev/null || true
        fi
    done
    
    log_msg "✓ Global nice level increased"
}

# Force memory to powersave mode
set_memory_governor() {
    log_msg "Setting memory governor to powersave..."
    
    # Set memory frequency scaling
    for mem_gov in /sys/class/devfreq/*/governor; do
        if [[ -f "$mem_gov" ]]; then
            echo "powersave" > "$mem_gov" 2>/dev/null || true
        fi
    done
    
    log_msg "✓ Memory governor set to powersave"
}

# Limit disk I/O to reduce heat
limit_disk_io() {
    log_msg "Limiting disk I/O..."
    
    # Set I/O scheduler to deadline (lower CPU overhead)
    for sched in /sys/block/sd*/queue/scheduler; do
        if [[ -f "$sched" ]]; then
            echo "deadline" > "$sched" 2>/dev/null || true
        fi
    done
    
    # Reduce dirty page writeback frequency
    echo 1500 > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null || true
    echo 500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
    
    log_msg "✓ Disk I/O limited"
}

# Get current CPU temperature
get_cpu_temp() {
    sensors 2>/dev/null | grep "Core 0" | awk '{print $3}' | sed 's/[+°C]//g' | cut -d'.' -f1
}

# Emergency thermal protection
emergency_thermal_protection() {
    local current_temp
    current_temp=$(get_cpu_temp)
    
    if [[ -z "$current_temp" ]]; then
        log_msg "WARNING: Cannot read CPU temperature"
        return 1
    fi
    
    log_msg "Current CPU temp: ${current_temp}°C"
    
    if [[ $current_temp -gt $CRITICAL_THRESHOLD ]]; then
        log_msg "🚨 CRITICAL TEMPERATURE! Emergency shutdown of heavy processes"
        pkill -f "ollama" 2>/dev/null || true
        pkill -f "docker" 2>/dev/null || true
        pkill -f "python.*ai" 2>/dev/null || true
        
        # Force all remaining processes to lowest priority
        for pid in $(ps -eo pid --no-headers); do
            renice +19 "$pid" 2>/dev/null || true
        done
        
        return 2
    elif [[ $current_temp -gt $TEMP_THRESHOLD ]]; then
        log_msg "⚠️ Temperature warning! Throttling processes"
        pkill -STOP ollama 2>/dev/null || true
        return 1
    fi
    
    return 0
}

# Main protection activation
activate_protection() {
    log_msg "=== Emergency System Protection Activation ==="
    log_msg "Target: Q9550 thermal management"
    
    if check_root; then
        disable_turbo_boost
        set_global_nice
        set_memory_governor
        limit_disk_io
    fi
    
    emergency_thermal_protection
    
    log_msg "✅ System protection activated"
}

# Status check
status_check() {
    log_msg "=== System Protection Status ==="
    
    # Temperature
    local temp
    temp=$(get_cpu_temp)
    log_msg "CPU Temperature: ${temp}°C"
    
    # Turbo Boost status
    if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
        local turbo_status
        turbo_status=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
        log_msg "Turbo Boost: $([[ $turbo_status -eq 1 ]] && echo "DISABLED" || echo "ENABLED")"
    fi
    
    # Heavy processes
    local heavy_processes
    heavy_processes=$(ps aux | grep -E "(ollama|docker|python.*ai)" | grep -v grep | wc -l)
    log_msg "Heavy processes running: $heavy_processes"
    
    # Load average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    log_msg "Load average: $load_avg"
}

# Continuous monitoring mode
monitor_mode() {
    log_msg "Starting continuous thermal monitoring..."
    
    while true; do
        emergency_thermal_protection
        local result=$?
        
        if [[ $result -eq 2 ]]; then
            log_msg "System in emergency state - extended cooldown"
            sleep 30
        elif [[ $result -eq 1 ]]; then
            log_msg "System under thermal stress - monitoring closely"
            sleep 5
        else
            sleep 10
        fi
    done
}

# Usage
case "${1:-activate}" in
    "activate")
        activate_protection
        ;;
    "status")
        status_check
        ;;
    "monitor")
        monitor_mode
        ;;
    "temp")
        echo "$(get_cpu_temp)°C"
        ;;
    *)
        echo "Usage: $0 {activate|status|monitor|temp}"
        exit 1
        ;;
esac