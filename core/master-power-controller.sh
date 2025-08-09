#!/bin/bash

# Master Power Controller - Unified Power Management System
# Central control hub for all power management operations

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
PERFORMANCE_SCRIPT="$BASE_DIR/scripts/performance_manager.sh"
AI_MANAGER="$BASE_DIR/scripts/ai_process_manager.sh"
CUSTOM_DAEMON="$BASE_DIR/daemons/custom-power-profiles-daemon.py"
RECOVERY_SCRIPT="$BASE_DIR/../SystemOptimization/recovery/auto-recovery-wrapper.sh"

LOG_FILE="/var/log/master-power-controller.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MASTER-POWER: $1" | tee -a "$LOG_FILE"
}

show_status() {
    echo "🔋 Master Power Controller Status:"
    echo "=================================="
    
    # Custom daemon status
    if systemctl is-active --quiet custom-power-profiles-daemon.service; then
        echo "✅ Custom Power Daemon: ACTIVE"
        powerprofilesctl get 2>/dev/null && echo "   Current Profile: $(powerprofilesctl get)"
    else
        echo "❌ Custom Power Daemon: INACTIVE"
    fi
    
    # GPU Monitor status
    if systemctl is-active --quiet gpu-monitor.service; then
        echo "✅ GPU Monitor: ACTIVE"
    else
        echo "❌ GPU Monitor: INACTIVE"
    fi
    
    # System load
    echo "📊 System Load: $(cat /proc/loadavg | awk '{print $1,$2,$3}')"
    
    # Memory usage
    echo "💾 Memory Usage: $(free -h | awk 'NR==2{printf "%.1fGi/%.1fGi (%.0f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
    
    # Available profiles
    echo "⚡ Available Profiles:"
    powerprofilesctl list 2>/dev/null | head -10
}

set_profile() {
    local profile="$1"
    
    if [ -z "$profile" ]; then
        echo "❌ Usage: $0 set [performance|balanced|power-saver]"
        return 1
    fi
    
    log_message "Setting power profile to: $profile"
    
    # Use powerprofilesctl (our custom one)
    if powerprofilesctl set "$profile"; then
        log_message "✅ Profile set to $profile successfully"
        
        # Trigger AI optimization
        if [ -f "$AI_MANAGER" ]; then
            log_message "🤖 Triggering AI optimization for $profile profile"
            "$AI_MANAGER" optimize &
        fi
        
        # Trigger System-Optimizer-Guardian Agent
        if command -v claude >/dev/null 2>&1; then
            log_message "🤖 Launching System-Optimizer-Guardian Agent"
            claude --agent system-optimizer-guardian \
                "Power profile changed to $profile. Optimize system accordingly: 1. Apply $profile specific optimizations 2. Monitor system performance 3. Adjust CPU/GPU states 4. Clear caches if needed" &
        fi
        
        echo "✅ Power profile set to: $profile"
        echo "🤖 AI optimization triggered"
        return 0
    else
        log_message "❌ Failed to set profile to $profile"
        echo "❌ Failed to set power profile"
        return 1
    fi
}

emergency_mode() {
    log_message "🚨 EMERGENCY MODE ACTIVATED"
    echo "🚨 Activating Emergency Mode..."
    
    # Use performance manager emergency mode
    if [ -f "$PERFORMANCE_SCRIPT" ]; then
        log_message "Running performance manager emergency mode"
        "$PERFORMANCE_SCRIPT" emergency
    fi
    
    # Trigger recovery
    if [ -f "$RECOVERY_SCRIPT" ]; then
        log_message "Running auto recovery"
        "$RECOVERY_SCRIPT" &
    fi
    
    echo "🚨 Emergency mode activated - System stabilizing..."
}

restart_services() {
    log_message "🔄 Restarting power management services"
    echo "🔄 Restarting services..."
    
    sudo systemctl restart custom-power-profiles-daemon.service
    sudo systemctl restart gpu-monitor.service
    
    sleep 3
    echo "✅ Services restarted"
}

run_tests() {
    echo "🧪 Running Power Management Tests:"
    echo "================================="
    
    # Test power daemon
    echo "Testing power daemon..."
    if systemctl is-active --quiet custom-power-profiles-daemon.service; then
        echo "✅ Power daemon: OK"
    else
        echo "❌ Power daemon: FAILED"
    fi
    
    # Test powerprofilesctl
    echo "Testing powerprofilesctl..."
    if powerprofilesctl list >/dev/null 2>&1; then
        echo "✅ PowerProfilesCtl: OK"
    else
        echo "❌ PowerProfilesCtl: FAILED"
    fi
    
    # Test profile switching
    echo "Testing profile switching..."
    current=$(powerprofilesctl get 2>/dev/null)
    if powerprofilesctl set balanced >/dev/null 2>&1; then
        echo "✅ Profile switching: OK"
        powerprofilesctl set "$current" >/dev/null 2>&1  # Restore
    else
        echo "❌ Profile switching: FAILED"
    fi
    
    # Test AI integration
    echo "Testing AI integration..."
    if command -v claude >/dev/null 2>&1; then
        echo "✅ Claude AI: Available"
    else
        echo "⚠️ Claude AI: Not available"
    fi
    
    echo "🧪 Test completed"
}

show_help() {
    echo "🔋 Master Power Controller"
    echo "========================="
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status                 Show system status"
    echo "  set [PROFILE]         Set power profile (performance|balanced|power-saver)"
    echo "  emergency             Activate emergency mode"
    echo "  restart               Restart power management services"
    echo "  test                  Run system tests"
    echo "  help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 set performance"
    echo "  $0 emergency"
    echo ""
}

main() {
    case "$1" in
        "status"|"")
            show_status
            ;;
        "set")
            set_profile "$2"
            ;;
        "emergency")
            emergency_mode
            ;;
        "restart")
            restart_services
            ;;
        "test")
            run_tests
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "❌ Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"