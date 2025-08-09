#!/bin/bash

#==============================================================================
# AI Process Manager v2.0 - Advanced AI process management with thermal protection
#==============================================================================
# Description: Manages AI processes (Claude, Gemini, etc.) with automatic 
#              thermal protection to prevent CPU overheating
# Author: PowerManagement System
# Version: 2.0
# License: MIT
#==============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

#==============================================================================
# CONFIGURATION CONSTANTS
#==============================================================================

readonly SCRIPT_NAME="AI Process Manager v2.0"
readonly VERSION="2.0.0"

# Temperature thresholds (Celsius)
readonly TEMP_WARNING_THRESHOLD=75
readonly TEMP_CRITICAL_THRESHOLD=79

# Process patterns to monitor
readonly AI_PROCESS_PATTERNS="claude|gemini|anthropic|python.*telegram|node.*claude"

# Paths
readonly POWER_MANAGER_PATH="/home/milhy777/Develop/Production/PowerManagement/scripts/performance_manager.sh"
readonly THERMAL_ZONE="/sys/class/thermal/thermal_zone0/temp"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

#==============================================================================
# LOGGING AND OUTPUT FUNCTIONS
#==============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}❌ ERROR:${NC} $1" >&2
}

log_critical() {
    echo -e "${RED}🚨 CRITICAL:${NC} $1" >&2
}

show_header() {
    echo -e "${PURPLE}🤖 ${SCRIPT_NAME}${NC}"
    echo -e "${PURPLE}$(printf '%*s' ${#SCRIPT_NAME} '' | tr ' ' '=')${NC}"
    echo ""
}

#==============================================================================
# TEMPERATURE MONITORING FUNCTIONS
#==============================================================================

get_cpu_temperature() {
    local temp_celsius=0
    
    # Try sensors command first (more reliable)
    if command -v sensors >/dev/null 2>&1; then
        temp_celsius=$(sensors -A | grep -E "Core [0-9]+:" | awk '{sum+=$3; count++} END {if(count>0) print int(sum/count); else print 0}' | head -1)
        if [[ $temp_celsius -gt 0 ]]; then
            echo "$temp_celsius"
            return 0
        fi
    fi
    
    # Fallback to thermal zone
    if [[ -r "$THERMAL_ZONE" ]]; then
        local temp_millicelsius=$(cat "$THERMAL_ZONE")
        temp_celsius=$((temp_millicelsius / 1000))
        echo "$temp_celsius"
        return 0
    fi
    
    log_error "Cannot read CPU temperature"
    echo "0"
    return 1
}

check_thermal_protection() {
    local current_temp
    current_temp=$(get_cpu_temperature)
    
    if [[ $current_temp -eq 0 ]]; then
        log_warning "Temperature monitoring unavailable - skipping thermal protection"
        return 0
    fi
    
    log_info "Current CPU temperature: ${current_temp}°C"
    
    # Critical temperature - emergency shutdown
    if [[ $current_temp -ge $TEMP_CRITICAL_THRESHOLD ]]; then
        log_critical "CPU temperature ${current_temp}°C >= ${TEMP_CRITICAL_THRESHOLD}°C - EMERGENCY THERMAL PROTECTION ACTIVATED!"
        emergency_thermal_shutdown
        return 2
    fi
    
    # Warning temperature - reduce performance
    if [[ $current_temp -ge $TEMP_WARNING_THRESHOLD ]]; then
        log_warning "CPU temperature ${current_temp}°C >= ${TEMP_WARNING_THRESHOLD}°C - Activating thermal throttling"
        activate_thermal_throttling
        return 1
    fi
    
    return 0
}

activate_thermal_throttling() {
    log_info "Activating thermal throttling..."
    
    # Set CPU governor to powersave
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -w "$cpu" ]]; then
            echo "powersave" | sudo tee "$cpu" >/dev/null 2>&1 || true
        fi
    done
    
    # Suspend Claude processes (instead of reducing priority)
    log_info "Suspending Claude processes for thermal protection..."
    local claude_pids
    claude_pids=$(pgrep -f "claude" || true)
    if [[ -n "$claude_pids" ]]; then
        for pid in $claude_pids; do
            kill -STOP "$pid" 2>/dev/null || true
        done
        log_success "Claude processes suspended for cooling"
    fi
    
    # Reduce other AI process priority
    reduce_ai_process_priority
    
    log_success "Thermal throttling activated - Claude suspended, CPU performance reduced"
}

emergency_thermal_shutdown() {
    log_critical "EMERGENCY THERMAL SHUTDOWN - CPU PROTECTION ACTIVE!"
    
    # 1. Suspend Claude, kill others immediately
    log_info "Suspending Claude and killing other AI processes for thermal protection..."
    suspend_ai_processes
    sleep 1
    kill_ai_processes_force
    
    # 2. Set minimum CPU performance
    log_info "Setting minimum CPU performance..."
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -w "$cpu" ]]; then
            echo "powersave" | sudo tee "$cpu" >/dev/null 2>&1 || true
        fi
    done
    
    # 3. Clear system caches to reduce load
    log_info "Clearing system caches..."
    sudo sync
    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true
    
    # 4. Kill high CPU processes
    log_info "Terminating high CPU usage processes..."
    sudo pkill -f cpulimit 2>/dev/null || true
    
    log_critical "Emergency thermal shutdown complete. System should cool down now."
    log_info "Monitor temperature with: watch sensors"
}

reduce_ai_process_priority() {
    local ai_pids
    ai_pids=$(pgrep -f "$AI_PROCESS_PATTERNS" || true)
    
    if [[ -n "$ai_pids" ]]; then
        log_info "Reducing AI process priority for thermal protection..."
        for pid in $ai_pids; do
            sudo renice +10 "$pid" 2>/dev/null || true
        done
        log_success "AI process priorities reduced"
    fi
}

#==============================================================================
# PROCESS MANAGEMENT FUNCTIONS
#==============================================================================

show_ai_processes() {
    echo -e "${CYAN}📊 Current AI Processes:${NC}"
    if ! ps aux | grep -E "$AI_PROCESS_PATTERNS" | grep -v grep | head -10; then
        log_info "No AI processes currently running"
    fi
    echo ""
    
    # Show current temperature
    local temp
    temp=$(get_cpu_temperature)
    if [[ $temp -gt 0 ]]; then
        if [[ $temp -ge $TEMP_CRITICAL_THRESHOLD ]]; then
            echo -e "${RED}🌡️  CPU Temperature: ${temp}°C (CRITICAL!)${NC}"
        elif [[ $temp -ge $TEMP_WARNING_THRESHOLD ]]; then
            echo -e "${YELLOW}🌡️  CPU Temperature: ${temp}°C (WARNING)${NC}"
        else
            echo -e "${GREEN}🌡️  CPU Temperature: ${temp}°C (OK)${NC}"
        fi
    fi
    echo ""
}

suspend_ai_processes() {
    log_info "Suspending AI processes..."
    
    local claude_pids
    local other_pids
    local suspended_count=0
    
    # Handle Claude processes specially - suspend instead of kill
    claude_pids=$(pgrep -f "claude" || true)
    if [[ -n "$claude_pids" ]]; then
        for pid in $claude_pids; do
            if kill -STOP "$pid" 2>/dev/null; then
                log_success "Claude process (PID $pid) suspended"
                ((suspended_count++))
            fi
        done
    fi
    
    # Handle other AI processes - terminate gracefully
    local other_patterns=("anthropic" "gemini" "python.*telegram" "python.*claude" "node.*claude" "node.*gemini")
    local killed_count=0
    
    for pattern in "${other_patterns[@]}"; do
        if pkill -f "$pattern" 2>/dev/null; then
            ((killed_count++))
        fi
    done
    
    if [[ $suspended_count -gt 0 ]]; then
        log_success "Claude processes suspended: $suspended_count"
    fi
    if [[ $killed_count -gt 0 ]]; then
        log_success "Other AI processes terminated: $killed_count"
    fi
    if [[ $suspended_count -eq 0 && $killed_count -eq 0 ]]; then
        log_info "No AI processes found"
    fi
}

resume_claude_processes() {
    log_info "Resuming suspended Claude processes..."
    
    local claude_pids
    local resumed_count=0
    
    claude_pids=$(pgrep -f "claude" || true)
    if [[ -n "$claude_pids" ]]; then
        for pid in $claude_pids; do
            if kill -CONT "$pid" 2>/dev/null; then
                log_success "Claude process (PID $pid) resumed"
                ((resumed_count++))
            fi
        done
    fi
    
    if [[ $resumed_count -gt 0 ]]; then
        log_success "Claude processes resumed: $resumed_count"
    else
        log_info "No suspended Claude processes found"
    fi
}

kill_ai_processes() {
    log_warning "Force terminating all AI processes (including Claude)..."
    
    local patterns=("claude" "anthropic" "gemini" "python.*telegram" "python.*claude" "node.*claude" "node.*gemini")
    local killed_count=0
    
    for pattern in "${patterns[@]}"; do
        if pkill -f "$pattern" 2>/dev/null; then
            ((killed_count++))
        fi
    done
    
    if [[ $killed_count -gt 0 ]]; then
        log_success "AI processes terminated ($killed_count patterns matched)"
    else
        log_info "No AI processes found to terminate"
    fi
}

kill_ai_processes_force() {
    log_warning "Force killing AI processes..."
    
    local patterns=("claude" "anthropic" "gemini" "python.*telegram" "python.*claude" "node.*claude" "node.*gemini")
    local killed_count=0
    
    for pattern in "${patterns[@]}"; do
        if pkill -9 -f "$pattern" 2>/dev/null; then
            ((killed_count++))
        fi
    done
    
    if [[ $killed_count -gt 0 ]]; then
        log_success "AI processes force killed ($killed_count patterns matched)"
    else
        log_info "No AI processes found to kill"
    fi
}

restart_ai_services() {
    log_info "Restarting AI services..."
    
    # Check thermal state before restart
    check_thermal_protection
    local thermal_status=$?
    
    if [[ $thermal_status -eq 2 ]]; then
        log_error "Cannot restart AI services - CPU too hot!"
        return 1
    elif [[ $thermal_status -eq 1 ]]; then
        log_warning "Restarting with thermal throttling active"
    fi
    
    # Restart Docker containers
    local containers=("claude-telegram-bot")
    local restarted_count=0
    
    for container in "${containers[@]}"; do
        if docker restart "$container" 2>/dev/null; then
            ((restarted_count++))
        fi
    done
    
    # Restart generic claude/gemini containers
    local claude_containers
    local gemini_containers
    claude_containers=$(docker ps -q --filter "name=claude" || true)
    gemini_containers=$(docker ps -q --filter "name=gemini" || true)
    
    for container in $claude_containers $gemini_containers; do
        if [[ -n "$container" ]] && docker restart "$container" 2>/dev/null; then
            ((restarted_count++))
        fi
    done
    
    if [[ $restarted_count -gt 0 ]]; then
        log_success "AI services restarted ($restarted_count containers)"
    else
        log_warning "No AI containers found to restart"
    fi
}

optimize_ai_processes() {
    log_info "Optimizing AI processes for stability..."
    
    # Check thermal state
    check_thermal_protection
    local thermal_status=$?
    
    if [[ $thermal_status -eq 2 ]]; then
        log_error "Cannot optimize - emergency thermal protection active!"
        return 1
    fi
    
    local ai_pids
    ai_pids=$(pgrep -f "$AI_PROCESS_PATTERNS" || true)
    
    if [[ -n "$ai_pids" ]]; then
        local optimized_count=0
        for pid in $ai_pids; do
            if sudo renice +5 "$pid" 2>/dev/null; then
                ((optimized_count++))
            fi
        done
        log_success "AI processes optimized for stability ($optimized_count processes)"
    else
        log_info "No AI processes found to optimize"
    fi
}

ai_performance_mode() {
    echo -e "${RED}🚀 AI PERFORMANCE MODE${NC} - Maximizing AI process performance!"
    
    # CRITICAL: Always check thermal state first
    check_thermal_protection
    local thermal_status=$?
    
    if [[ $thermal_status -eq 2 ]]; then
        log_critical "CANNOT ACTIVATE PERFORMANCE MODE - CPU TOO HOT!"
        log_info "Cool down system first, then retry"
        return 1
    elif [[ $thermal_status -eq 1 ]]; then
        log_warning "Performance mode with thermal throttling - reduced performance expected"
    fi
    
    # 1. Activate system performance mode (if available and temperature allows)
    if [[ -f "$POWER_MANAGER_PATH" ]] && [[ $thermal_status -eq 0 ]]; then
        log_info "Activating system performance mode..."
        "$POWER_MANAGER_PATH" performance >/dev/null 2>&1 || log_warning "System performance mode activation failed"
    fi
    
    # 2. Set AI processes to highest priority (if temperature allows)
    log_info "Setting AI processes to high priority..."
    local ai_pids
    ai_pids=$(pgrep -f "$AI_PROCESS_PATTERNS" || true)
    
    if [[ -n "$ai_pids" ]]; then
        local priority_count=0
        for pid in $ai_pids; do
            local priority=-5
            # Highest priority for Claude CLI (if thermal conditions allow)
            if [[ $thermal_status -eq 0 ]] && ps -p "$pid" -o comm= | grep -q "claude"; then
                priority=-10
                sudo renice $priority "$pid" 2>/dev/null && log_success "Claude CLI (PID $pid): priority $priority (highest)" && ((priority_count++))
            else
                # Reduced priority if thermal throttling active
                if [[ $thermal_status -eq 1 ]]; then
                    priority=0
                fi
                sudo renice $priority "$pid" 2>/dev/null && log_info "AI process (PID $pid): priority $priority" && ((priority_count++))
            fi
        done
        
        if [[ $priority_count -eq 0 ]]; then
            log_warning "No AI processes could be prioritized"
        fi
    else
        log_info "No AI processes found"
    fi
    
    # 3. Remove CPU limits (only if temperature is safe)
    if [[ $thermal_status -eq 0 ]]; then
        sudo pkill cpulimit 2>/dev/null || true
        log_info "CPU limits removed"
    fi
    
    # 4. Memory optimization (if temperature allows)
    if [[ $thermal_status -eq 0 ]]; then
        log_info "Optimizing memory for AI processes..."
        sudo sync
        log_success "Memory optimization complete"
    fi
    
    echo ""
    if [[ $thermal_status -eq 0 ]]; then
        echo -e "${GREEN}🔥 AI PERFORMANCE MODE ACTIVE!${NC}"
        echo "   • System: Full performance"
        echo "   • Claude CLI: Highest priority (-10)"  
        echo "   • Other AI: High priority (-5)"
        echo "   • Memory: Optimized"
        echo "   • CPU limits: Removed"
        echo "   • Thermal protection: Monitoring active"
    else
        echo -e "${YELLOW}🔥 AI PERFORMANCE MODE ACTIVE (THERMAL LIMITED)${NC}"
        echo "   • System: Thermal throttling active"
        echo "   • AI processes: Reduced priority"
        echo "   • Thermal protection: Active"
    fi
    
    # Monitor temperature for a few seconds
    log_info "Monitoring temperature for 10 seconds..."
    for i in {1..10}; do
        local temp
        temp=$(get_cpu_temperature)
        echo -n "Temperature: ${temp}°C "
        if [[ $temp -ge $TEMP_WARNING_THRESHOLD ]]; then
            echo -e "${YELLOW}(WARNING)${NC}"
            if [[ $temp -ge $TEMP_CRITICAL_THRESHOLD ]]; then
                log_critical "Temperature reached critical level during performance mode!"
                emergency_thermal_shutdown
                return 1
            fi
        else
            echo -e "${GREEN}(OK)${NC}"
        fi
        sleep 1
    done
}

monitor_ai_processes() {
    log_info "Monitoring AI processes (Press Ctrl+C to stop)..."
    
    while true; do
        clear
        echo -e "${PURPLE}=== AI PROCESS MONITOR $(date) ===${NC}"
        echo ""
        
        # Show AI processes
        show_ai_processes
        
        # Show system load
        echo -e "${CYAN}💻 System Load:${NC}"
        uptime
        echo ""
        
        # Show memory usage  
        echo -e "${CYAN}💾 Memory Usage:${NC}"
        free -h
        echo ""
        
        # Show top AI processes
        echo -e "${CYAN}📈 Top AI Processes:${NC}"
        ps aux --sort=-%cpu | grep -E "$AI_PROCESS_PATTERNS" | grep -v grep | head -5 || echo "No AI processes found"
        echo ""
        
        # Thermal status
        check_thermal_protection >/dev/null 2>&1
        local thermal_status=$?
        if [[ $thermal_status -eq 2 ]]; then
            echo -e "${RED}🚨 THERMAL STATUS: CRITICAL - EMERGENCY PROTECTION ACTIVE${NC}"
        elif [[ $thermal_status -eq 1 ]]; then
            echo -e "${YELLOW}⚠️  THERMAL STATUS: WARNING - THROTTLING ACTIVE${NC}"
        else
            echo -e "${GREEN}✅ THERMAL STATUS: OK${NC}"
        fi
        echo ""
        
        sleep 3
    done
}

emergency_mode() {
    echo -e "${RED}🚨 EMERGENCY MODE${NC} - Complete system protection!"
    
    log_critical "Activating emergency mode..."
    
    # 1. Suspend Claude first, then kill others if needed
    suspend_ai_processes
    sleep 2
    kill_ai_processes_force
    sleep 2
    
    # 2. Emergency thermal shutdown
    emergency_thermal_shutdown
    
    log_success "Emergency mode complete - system should stabilize"
}

#==============================================================================
# DEPENDENCY CHECKING
#==============================================================================

check_dependencies() {
    local missing_deps=()
    
    # Check for sensors
    if ! command -v sensors >/dev/null 2>&1; then
        missing_deps+=("lm-sensors")
    fi
    
    # Check for thermal zone
    if [[ ! -r "$THERMAL_ZONE" ]]; then
        log_warning "Thermal zone not accessible - temperature monitoring may be limited"
    fi
    
    # Check for cpulimit (optional)
    if ! command -v cpulimit >/dev/null 2>&1; then
        log_info "cpulimit not found (optional for advanced CPU limiting)"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: sudo apt install ${missing_deps[*]}"
    fi
}

#==============================================================================
# HELP AND VERSION FUNCTIONS
#==============================================================================

show_version() {
    echo "$SCRIPT_NAME v$VERSION"
    echo "Thermal protection: Warning at ${TEMP_WARNING_THRESHOLD}°C, Critical at ${TEMP_CRITICAL_THRESHOLD}°C"
}

show_help() {
    show_header
    show_version
    echo ""
    echo "USAGE:"
    echo "  $0 COMMAND [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "  show        - Show current AI processes and thermal status"
    echo "  suspend     - Suspend Claude processes, terminate others"
    echo "  resume      - Resume suspended Claude processes"
    echo "  kill        - Force terminate all AI processes (including Claude)"
    echo "  restart     - Restart AI services (with thermal check)"
    echo "  optimize    - Optimize AI processes for stability"
    echo "  performance - 🚀 AI PERFORMANCE MODE (with thermal protection)"
    echo "  monitor     - Real-time monitoring of AI processes and temperature"
    echo "  emergency   - 🚨 Emergency mode - suspend/kill processes and cool system"
    echo "  temp        - Show current CPU temperature"
    echo "  deps        - Check system dependencies"
    echo "  version     - Show version information"
    echo "  help        - Show this help message"
    echo ""
    echo "THERMAL PROTECTION:"
    echo "  • Warning threshold: ${TEMP_WARNING_THRESHOLD}°C (automatic throttling)"
    echo "  • Critical threshold: ${TEMP_CRITICAL_THRESHOLD}°C (emergency shutdown)"
    echo "  • Real-time monitoring in all modes"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 show                    # Show processes and temperature"
    echo "  $0 suspend                 # Suspend Claude, terminate others"
    echo "  $0 resume                  # Resume suspended Claude processes"
    echo "  $0 performance             # Activate performance mode with thermal monitoring"
    echo "  $0 monitor                 # Live monitoring dashboard"
    echo ""
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    # Detect CI environment
    if [[ "${CI:-false}" == "true" ]]; then
        log_info "Running in CI environment - some features may be limited"
        # In CI, skip operations that require hardware access
        export CI_MODE="true"
    fi
    
    # Check if running as root (some operations need sudo)
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root - be careful with system changes"
    fi
    
    # Parse command line arguments
    case "${1:-help}" in
        "show")
            show_header
            show_ai_processes
            ;;
        "suspend")
            show_header
            suspend_ai_processes
            ;;
        "resume")
            show_header
            resume_claude_processes
            ;;
        "kill")
            show_header
            kill_ai_processes
            ;;
        "restart")
            show_header
            restart_ai_services
            ;;
        "optimize")
            show_header  
            optimize_ai_processes
            ;;
        "performance"|"ai-perf"|"max")
            show_header
            ai_performance_mode
            ;;
        "monitor")
            monitor_ai_processes
            ;;
        "emergency")
            show_header
            emergency_mode
            ;;
        "temp"|"temperature")
            local temp
            temp=$(get_cpu_temperature)
            echo "CPU Temperature: ${temp}°C"
            if [[ $temp -ge $TEMP_CRITICAL_THRESHOLD ]]; then
                echo -e "${RED}Status: CRITICAL${NC}"
                exit 2
            elif [[ $temp -ge $TEMP_WARNING_THRESHOLD ]]; then
                echo -e "${YELLOW}Status: WARNING${NC}"
                exit 1
            else
                echo -e "${GREEN}Status: OK${NC}"
            fi
            ;;
        "deps"|"dependencies")
            show_header
            check_dependencies
            ;;
        "version")
            show_version
            ;;
        "help"|"-h"|"--help"|*)
            show_help
            if [[ "${1:-}" != "help" && "${1:-}" != "-h" && "${1:-}" != "--help" ]]; then
                log_error "Unknown command: ${1:-}"
                exit 1
            fi
            ;;
    esac
}

# Execute main function with all arguments
main "$@"