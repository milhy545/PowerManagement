#!/bin/bash
# 🚀 Enable CPU Frequency Scaling for Core 2 Quad Q9550
# Automaticky načte správné moduly a aktivuje hardware scaling

set -e

readonly LOG_FILE="/tmp/cpu_scaling_setup.log"

log() {
    echo "$(date '+%H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

show_current_state() {
    echo "🖥️  Current CPU Scaling State"
    echo "============================="
    
    # CPU model
    echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    
    # Current frequency
    echo "Current frequency:"
    grep 'cpu MHz' /proc/cpuinfo | head -4
    
    # Check if cpufreq is available
    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
        echo ""
        echo "✅ CPUfreq is ACTIVE"
        echo "Available governors:"
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "Unknown"
        echo "Current governor:"
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "Unknown"
        echo "Frequency range:"
        echo "  Min: $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null || echo "Unknown") kHz"
        echo "  Max: $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo "Unknown") kHz"
        echo "  Current: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "Unknown") kHz"
    else
        echo ""
        echo "❌ CPUfreq is NOT active"
    fi
    
    # Check loaded modules
    echo ""
    echo "🔧 Relevant kernel modules:"
    lsmod | grep -E "(acpi_cpufreq|intel_pstate|p4_clockmod|speedstep)" || echo "  None found"
    
    # Temperature
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [ -n "$temp" ]; then
            temp_c=$((temp / 1000))
            echo ""
            echo "🌡️  Temperature: ${temp_c}°C"
        fi
    fi
}

enable_cpu_scaling() {
    log "🚀 Enabling CPU frequency scaling for Core 2 Quad Q9550"
    
    # Check if we need sudo
    if [ "$EUID" -ne 0 ]; then
        echo ""
        echo "⚠️  This script needs sudo to load kernel modules"
        echo ""
        echo "📋 Manual commands to run with sudo:"
        echo "   sudo modprobe acpi_cpufreq"
        echo "   sudo modprobe cpufreq_ondemand" 
        echo "   sudo modprobe cpufreq_conservative"
        echo "   sudo modprobe cpufreq_powersave"
        echo ""
        echo "🔧 Or install cpufrequtils:"
        echo "   sudo apt install cpufrequtils"
        echo ""
        
        # Try to generate commands for user
        cat << 'EOF' > /tmp/enable_cpu_scaling_commands.sh
#!/bin/bash
# Commands to enable CPU scaling (run with sudo)

echo "🚀 Loading CPU frequency modules..."

# Load ACPI CPU frequency driver
modprobe acpi_cpufreq

# Load CPU frequency governors  
modprobe cpufreq_ondemand
modprobe cpufreq_conservative 
modprobe cpufreq_powersave
modprobe cpufreq_performance

# Check if it worked
if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
    echo "✅ CPU scaling enabled!"
    
    # Set powersave governor for all CPUs
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$cpu" ]; then
            echo "powersave" > "$cpu" 2>/dev/null || echo "ondemand" > "$cpu" 2>/dev/null
        fi
    done
    
    echo "🔋 Set to powersave/ondemand governor"
    
    # Show new state
    echo ""
    echo "📊 New CPU state:"
    for i in 0 1 2 3; do
        if [ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq" ]; then
            freq=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq)
            gov=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor)
            echo "  CPU$i: ${freq} kHz ($gov)"
        fi
    done
else
    echo "❌ CPU scaling failed to enable"
    
    # Check what went wrong
    echo "🔍 Diagnostics:"
    echo "Loaded modules:"
    lsmod | grep -E "(acpi_cpufreq|intel_pstate|cpufreq)"
    
    echo ""
    echo "Kernel support:"
    zcat /proc/config.gz | grep -E "CONFIG_CPU_FREQ|CONFIG_ACPI" 2>/dev/null || echo "Config not available"
fi
EOF

        chmod +x /tmp/enable_cpu_scaling_commands.sh
        
        echo "📜 Generated script: /tmp/enable_cpu_scaling_commands.sh"
        echo "🚀 Run: sudo /tmp/enable_cpu_scaling_commands.sh"
        
        return 1
    fi
    
    # If we have sudo, try to load modules
    log "Loading acpi_cpufreq module..."
    modprobe acpi_cpufreq || log "⚠️  acpi_cpufreq failed"
    
    log "Loading governor modules..."
    modprobe cpufreq_ondemand || log "⚠️  ondemand failed"
    modprobe cpufreq_conservative || log "⚠️  conservative failed" 
    modprobe cpufreq_powersave || log "⚠️  powersave failed"
    
    # Check if it worked
    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
        log "✅ CPU scaling successfully enabled!"
        
        # Set conservative governor (good for older CPUs)
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [ -f "$cpu" ]; then
                echo "conservative" > "$cpu" 2>/dev/null || echo "ondemand" > "$cpu" 2>/dev/null
            fi
        done
        
        log "🔋 Set to conservative governor for better temperature control"
    else
        log "❌ CPU scaling failed to enable"
    fi
}

install_cpufrequtils() {
    echo "📦 Installing cpufrequtils for easy CPU management..."
    echo ""
    echo "Manual installation commands:"
    echo "  sudo apt update"
    echo "  sudo apt install cpufrequtils"
    echo ""
    echo "After installation, you can use:"
    echo "  cpufreq-info           # Show current state"
    echo "  sudo cpufreq-set -g powersave    # Set powersave mode"
    echo "  sudo cpufreq-set -g conservative # Set conservative mode"
    echo "  sudo cpufreq-set -g ondemand     # Set ondemand mode"
}

test_temperature_scaling() {
    echo ""
    echo "🌡️  Temperature-based scaling test"
    echo "================================="
    
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [ -n "$temp" ]; then
            temp_c=$((temp / 1000))
            echo "Current temperature: ${temp_c}°C"
            
            if [ $temp_c -gt 70 ]; then
                echo "🔥 Temperature > 70°C - consider powersave governor"
            elif [ $temp_c -gt 60 ]; then
                echo "⚠️  Temperature > 60°C - conservative governor recommended"
            else
                echo "✅ Temperature OK - any governor fine"
            fi
        fi
    else
        echo "🤷 Temperature sensors not available"
    fi
}

# Main
case "${1:-status}" in
    "status")
        show_current_state
        ;;
    "enable")
        enable_cpu_scaling
        ;;
    "install")
        install_cpufrequtils
        ;;
    "test")
        test_temperature_scaling
        ;;
    "help")
        echo "🚀 CPU Frequency Scaling Setup for Core 2 Quad Q9550"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  status   - Show current CPU scaling state"
        echo "  enable   - Enable CPU frequency scaling (needs sudo)"
        echo "  install  - Show cpufrequtils installation commands"
        echo "  test     - Test temperature-based recommendations"
        echo ""
        echo "🎯 Goal: Enable hardware CPU scaling to reduce heat and power"
        echo "   Instead of fixed 2.8GHz, CPU will scale 1.6-2.8GHz based on load"
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Use '$0 help' for usage"
        exit 1
        ;;
esac