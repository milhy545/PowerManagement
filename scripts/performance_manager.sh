#!/bin/bash

# Performance Manager - Universal Power Management for Linux Systems
# Version: 3.0 - Universal Hardware Support
# Author: PowerManagement Team
# License: MIT

# Exit on any error for safety
set -euo pipefail

# Configuration - Dynamic path detection
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SRC_DIR="$INSTALL_DIR/src"
readonly LOG_DIR="${POWER_MGMT_LOG_DIR:-/tmp}"
readonly LOG_FILE="$LOG_DIR/performance_manager.log"
readonly MAX_PROCESSES=10

# Dynamic script paths
readonly CPU_FREQ_MANAGER="$SRC_DIR/frequency/universal_cpu_manager.py"
readonly AI_MANAGER="$SCRIPT_DIR/ai_process_manager.sh"
readonly EMERGENCY_CLEANUP="$SCRIPT_DIR/EMERGENCY_CLEANUP.sh"

# Safety check - prevent multiple instances
check_running_instances() {
    local count
    count=$(pgrep -f "$SCRIPT_NAME" | wc -l)
    if [ "$count" -gt "$MAX_PROCESSES" ]; then
        echo "🚨 ERROR: Too many instances running ($count). Aborting for safety!"
        exit 1
    fi
}

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Safety timeout wrapper
safe_exec() {
    local cmd="$1"
    local timeout_sec="${2:-5}"
    
    log "Executing (timeout ${timeout_sec}s): $cmd"
    if ! timeout "$timeout_sec" bash -c "$cmd" 2>/dev/null; then
        log "⚠️ Command timeout or failed: $cmd"
        return 1
    fi
    return 0
}

# Safe sudo wrapper for security
safe_sudo() {
    local cmd="$1"
    local timeout_sec="${2:-5}"
    
    # In CI mode, skip sudo operations
    if [[ "${CI:-false}" == "true" ]]; then
        log "CI Mode: Skipping sudo operation"
        return 0
    fi
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log "⚠️ No sudo access for: $cmd"
        return 1
    fi
    
    # Execute with timeout
    if timeout "$timeout_sec" sudo bash -c "$cmd" 2>/dev/null; then
        return 0
    else
        log "⚠️ Sudo command failed or timeout: $cmd"
        return 1
    fi
}

# Performance Manager Header
show_header() {
    echo "⚡ Performance Manager v3.0 - Universal Edition"
    echo "==============================================="
    echo "🛡️ Safe mode: Process monitoring enabled"
    echo "📁 Install: $INSTALL_DIR"
    check_running_instances
}

# System status
get_current_status() {
    echo "📊 Current Performance Status:"
    echo ""
    
    # CPU info
    echo "🖥️  CPU:"
    local cpu_model cpu_mhz
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    cpu_mhz=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    echo "  Model: $cpu_model"
    echo "  Current: ${cpu_mhz} MHz (Max: 2833 MHz)"
    
    # GPU info (safely) - auto-detect GPU card
    echo ""
    echo "🎮 GPU:"
    local gpu_card gpu_profile gpu_method
    # Find first GPU with power_profile support
    gpu_card=""
    for card in /sys/class/drm/card[0-9]; do
        if [ -f "$card/device/power_profile" 2>/dev/null ]; then
            gpu_card="$card"
            break
        fi
    done

    if [ -n "$gpu_card" ]; then
        gpu_profile=$(cat "$gpu_card/device/power_profile" 2>/dev/null || echo "unknown")
        gpu_method=$(cat "$gpu_card/device/power_method" 2>/dev/null || echo "unknown")
        echo "  Card: $(basename "$gpu_card")"
        echo "  Power Profile: $gpu_profile"
        echo "  Power Method: $gpu_method"
    else
        echo "  No GPU with power management found"
    fi
    
    # Power Profiles (safely)
    echo ""
    echo "🔋 System Power Profile:"
    if command -v powerprofilesctl >/dev/null 2>&1; then
        local current_profile available_profiles
        current_profile=$(timeout 3 powerprofilesctl get 2>/dev/null || echo "unknown")
        available_profiles=$(timeout 3 powerprofilesctl list 2>/dev/null | grep -E '^\s*[a-z-]+:' | sed 's/^[[:space:]]*//' | cut -d: -f1 | tr '\n' ' ' || echo "unknown")
        echo "  Current: $current_profile"
        echo "  Available: $available_profiles"
    else
        echo "  Power Profiles Daemon: Not available"
    fi
    
    # System load
    echo ""
    echo "📈 System Load:"
    uptime
    echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2" ("int($3/$2*100)"%)"}')"
    echo "Processes: $(pgrep -f "$SCRIPT_NAME" | wc -l)/$MAX_PROCESSES allowed"
}

# Performance profile
set_performance_profile() {
    log "🚀 Setting PERFORMANCE profile..."
    
    # System power profile (safely)
    if command -v powerprofilesctl >/dev/null 2>&1; then
        if safe_sudo "powerprofilesctl set performance" 8; then
            log "✅ System: performance mode set"
        else
            log "⚠️ System: performance mode failed"
        fi
    fi
    
    # GPU high performance (safely) - auto-detect GPU
    local gpu_card
    for card in /sys/class/drm/card[0-9]; do
        if [ -f "$card/device/power_profile" 2>/dev/null ]; then
            if safe_sudo "echo 'high' > $card/device/power_profile" 3; then
                log "✅ GPU: high power mode set ($(basename "$card"))"
            fi
            break
        fi
    done

    # CPU frequency to maximum (universal manager)
    if [ -f "$CPU_FREQ_MANAGER" ]; then
        if safe_exec "python3 '$CPU_FREQ_MANAGER' profile performance" 10; then
            log "✅ CPU: performance frequency set"
        else
            log "⚠️ CPU: frequency control failed"
        fi
    fi
    
    # AI processes normal priority
    local ai_pids
    ai_pids=$(pgrep -f "claude\|gemini\|python.*telegram" || true)
    if [ -n "$ai_pids" ]; then
        for pid in $ai_pids; do
            renice 0 "$pid" 2>/dev/null || true
        done
        log "✅ AI processes: normal priority"
    fi
    
    echo "🔥 PERFORMANCE MODE ACTIVE - Full 2.83GHz CPU + High GPU!"
}

# Balanced profile  
set_balanced_profile() {
    log "⚖️ Setting BALANCED profile..."
    
    # System balanced (safely)
    if command -v powerprofilesctl >/dev/null 2>&1; then
        if safe_sudo "powerprofilesctl set balanced" 8; then
            log "✅ System: balanced mode set"
        else
            log "⚠️ System: balanced mode failed"
        fi
    fi
    
    # CPU frequency to balanced (universal manager)
    if [ -f "$CPU_FREQ_MANAGER" ]; then
        if safe_exec "python3 '$CPU_FREQ_MANAGER' profile balanced" 10; then
            log "✅ CPU: balanced frequency set"
        else
            log "⚠️ CPU: frequency control failed"
        fi
    fi

    # GPU default (safely) - auto-detect GPU
    local gpu_card
    for card in /sys/class/drm/card[0-9]; do
        if [ -f "$card/device/power_profile" 2>/dev/null ]; then
            if safe_sudo "echo 'default' > $card/device/power_profile" 3; then
                log "✅ GPU: default power mode set ($(basename "$card"))"
            fi
            break
        fi
    done
    
    # AI processes slightly lower priority
    local ai_pids
    ai_pids=$(pgrep -f "claude\|gemini\|python.*telegram" || true)
    if [ -n "$ai_pids" ]; then
        for pid in $ai_pids; do
            renice +5 "$pid" 2>/dev/null || true
        done
        log "✅ AI processes: lower priority set"
    fi
    
    echo "⚖️ BALANCED MODE ACTIVE - Smart power management"
}

# Power save profile
set_powersave_profile() {
    log "🔋 Setting POWER SAVE profile..."
    
    # System power-saver (safely)
    if command -v powerprofilesctl >/dev/null 2>&1; then
        if safe_sudo "powerprofilesctl set power-saver" 8; then
            log "✅ System: power-saver mode set"
        else
            log "⚠️ System: power-saver mode failed"
        fi
    fi
    
    # CPU frequency to power save (universal manager)
    if [ -f "$CPU_FREQ_MANAGER" ]; then
        if safe_exec "python3 '$CPU_FREQ_MANAGER' profile powersave" 10; then
            log "✅ CPU: power save frequency set"
        else
            log "⚠️ CPU: frequency control failed"
        fi
    fi

    # GPU low power (safely) - auto-detect GPU
    local gpu_card
    for card in /sys/class/drm/card[0-9]; do
        if [ -f "$card/device/power_profile" 2>/dev/null ]; then
            if safe_sudo "echo 'low' > $card/device/power_profile" 3; then
                log "✅ GPU: low power mode set ($(basename "$card"))"
            fi
            break
        fi
    done
    
    # AI processes lower priority
    local ai_pids
    ai_pids=$(pgrep -f "claude\|gemini\|python.*telegram" || true)
    if [ -n "$ai_pids" ]; then
        for pid in $ai_pids; do
            renice +10 "$pid" 2>/dev/null || true
        done
        log "✅ AI processes: low priority set"
    fi
    
    echo "🔋 POWER SAVE MODE ACTIVE - Maximum stability, minimum heat"
}

# Emergency safe mode
set_emergency_profile() {
    log "🚨 Setting EMERGENCY profile..."

    # CPU frequency to emergency minimum (FIRST - most important)
    if [ -f "$CPU_FREQ_MANAGER" ]; then
        if safe_exec "python3 '$CPU_FREQ_MANAGER' profile emergency" 10; then
            log "✅ CPU: EMERGENCY frequency set to minimum"
        else
            log "⚠️ CPU: emergency frequency control failed"
        fi
    fi

    # Kill all related processes first
    pkill -f "powerprofilesctl" 2>/dev/null || true
    sleep 1

    # Emergency AI cleanup
    if [ -f "$AI_MANAGER" ]; then
        "$AI_MANAGER" emergency || true
    fi

    # Minimal power settings
    if command -v powerprofilesctl >/dev/null 2>&1; then
        safe_sudo "powerprofilesctl set power-saver" 5 || true
    fi

    # GPU minimum (safely) - auto-detect GPU
    local gpu_card
    for card in /sys/class/drm/card[0-9]; do
        if [ -f "$card/device/power_profile" 2>/dev/null ]; then
            if safe_sudo "echo 'low' > $card/device/power_profile" 3; then
                log "✅ GPU: emergency low power mode set ($(basename "$card"))"
            fi
            break
        fi
    done

    # Clear memory (safe approach)
    sync
    # Drop caches only if we have sudo access
    if [[ "${CI:-false}" != "true" ]] && sudo -n true 2>/dev/null; then
        sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true
    fi

    # Run EMERGENCY_CLEANUP if available
    if [ -f "$EMERGENCY_CLEANUP" ]; then
        log "🧹 Running emergency cleanup"
        "$EMERGENCY_CLEANUP" &
    fi

    log "🚨 EMERGENCY MODE - Minimal power to prevent thermal shutdown"
    echo "🚨 EMERGENCY MODE - System stabilized"
}

# Test mode
test_mode() {
    echo "🧪 TEST MODE - Dry run simulation"
    echo ""
    echo "Would execute:"
    echo "  - Power profile changes"
    echo "  - GPU power adjustments"  
    echo "  - AI process priority changes"
    echo ""
    echo "Current system state:"
    get_current_status
    echo ""
    echo "✅ Test completed safely - no changes made"
}

# Main menu
main() {
    show_header
    
    case "${1:-}" in
        "performance"|"perf"|"high")
            set_performance_profile
            ;;
        "balanced"|"default"|"normal")
            set_balanced_profile
            ;;
        "powersave"|"save"|"low")
            set_powersave_profile
            ;;
        "emergency"|"safe")
            set_emergency_profile
            ;;
        "status"|"info")
            get_current_status
            ;;
        "test"|"dry-run")
            test_mode
            ;;
        "log")
            echo "📝 Recent log entries:"
            tail -20 "$LOG_FILE" 2>/dev/null || echo "No log file found"
            ;;
        *)
            echo "⚡ Performance Manager Commands:"
            echo "  performance  - Full 2.83GHz CPU + High GPU (gaming/work)"
            echo "  balanced     - Smart power management (daily use)"
            echo "  powersave    - Low power mode (stability/battery)"
            echo "  emergency    - Emergency mode (prevent blackscreen)"
            echo "  status       - Show current performance status"
            echo "  test         - Test mode (dry run, no changes)"
            echo "  log          - Show recent log entries"
            echo ""
            echo "Quick aliases:"
            echo "  🔥 perf/high  = maximum performance"
            echo "  ⚖️ balanced   = smart management"  
            echo "  🔋 save/low   = power saving"
            echo "  🚨 emergency  = blackscreen prevention"
            echo ""
            get_current_status
            ;;
    esac
}

# Execute main with all arguments
main "$@"