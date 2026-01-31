# PowerManagement Integrations

## 🔗 Overview

PowerManagement v3.1 now provides integration with other system tools and workflows, creating a unified monitoring and management ecosystem.

## 📋 Available Integrations

### 1. MyMenu Integration (dmenu Launcher)

Add PowerManagement capabilities to your MyMenu dmenu launcher.

**Features:**
- 🌡️ Power & Thermal category in dmenu
- Quick access to all power profiles
- GPU and sensor monitoring
- Fan control submenu
- Monitoring service launcher

**Installation:**

```bash
# Automatic integration (creates backup)
bash integrations/mymenu_patch.sh /path/to/MyMenu

# Manual integration
# Add PowerManagement commands to your dmenu-launcher.sh
source integrations/mymenu_integration.sh
```

**Usage:**

1. Launch MyMenu: `bash /path/to/MyMenu/dmenu-launcher.sh`
2. Select: `🌡️ Power & Thermal`
3. Choose action:
   - `🔥 Performance Mode` - Max performance
   - `⚖️ Balanced Mode` - Balanced power
   - `🔋 Power Save Mode` - Battery saver
   - `🚨 Emergency Mode` - Thermal emergency
   - `📊 Current Status` - System overview
   - `🎮 GPU Metrics` - GPU details
   - `🌡️ All Sensors` - Complete sensor list
   - `💨 Fan Status` - Fan speeds
   - `💨 Fan Control` - Manual fan control
   - `📈 Start Monitoring` - Launch monitoring service
   - `📖 Documentation` - View docs

**Menu Structure:**

```
MyMenu
├── ...
├── 🌡️ Power & Thermal
│   ├── Power Profiles
│   │   ├── 🔥 Performance Mode
│   │   ├── ⚖️ Balanced Mode
│   │   ├── 🔋 Power Save Mode
│   │   └── 🚨 Emergency Mode
│   ├── Monitoring
│   │   ├── 📊 Current Status
│   │   ├── 🎮 GPU Metrics
│   │   ├── 🌡️ All Sensors
│   │   └── 💨 Fan Status
│   ├── Control
│   │   └── 💨 Fan Control
│   │       ├── 🌀 30% Silent
│   │       ├── 🌀 50% Normal
│   │       ├── 🌀 75% High
│   │       ├── 🌀 100% Max
│   │       └── 🔄 Auto Mode
│   └── Services
│       ├── 📈 Start Monitoring
│       └── 📖 Documentation
└── ...
```

**Uninstall:**

```bash
# Restore from backup
cd /path/to/MyMenu
cp dmenu-launcher.sh.backup.YYYYMMDD_HHMMSS dmenu-launcher.sh
```

---

### 2. claude-tools-monitor Integration

Integrate system power/thermal monitoring into Claude AI session monitoring.

**Features:**
- 📊 Real-time CPU/GPU temperature logging during Claude sessions
- ⚡ Thermal throttling protection (warn when temps critical)
- 💨 Fan speed tracking
- 🔌 Power consumption logging
- 📝 JSON metrics log for analysis

**Installation:**

```bash
# Copy integration to claude-tools-monitor
cp integrations/power_integration.py /path/to/claude-tools-monitor/integrations/

# Set PowerManagement directory
export POWER_MGMT_DIR=/home/user/PowerManagement
```

**Usage:**

```python
from integrations.power_integration import PowerMetricsLogger

# Initialize logger
logger = PowerMetricsLogger(log_file="/tmp/claude_power_metrics.log")

# Get current metrics
metrics = logger.get_current_metrics()
print(f"CPU: {metrics['cpu_temp']}°C")
print(f"GPU: {metrics['gpu_temp']}°C")

# Check thermal status
if logger.should_throttle_claude():
    print("🚨 CRITICAL: Consider pausing Claude!")

# Log metrics with Claude activity
logger.log_metrics(claude_activity="code generation")
```

**Automatic Monitoring:**

The integration automatically monitors:

| Metric | Source | Purpose |
|--------|--------|---------|
| CPU Temperature | UniversalSensorDetector | Thermal throttling detection |
| GPU Temperature | UniversalGPUMonitor | GPU workload monitoring |
| CPU Fan RPM | Fan sensors | Cooling efficiency |
| GPU Fan RPM | GPU monitor | GPU cooling |
| GPU Power | GPU monitor | Power consumption |

**Thermal Protection:**

The integration provides automatic thermal protection:

```python
# Check if should throttle
if logger.should_throttle_claude():
    # CPU temperature >= critical threshold (85% of max)
    # Recommend pausing intensive operations
```

**Log Format:**

```
2025-11-18T22:45:06 | Claude: code generation | CPU: 45.0°C GPU: 62.0°C Fan: 1245RPM GPU Power: 245W
2025-11-18T22:45:11 | Claude: testing        | CPU: 46.0°C GPU: 63.0°C Fan: 1250RPM GPU Power: 240W
2025-11-18T22:45:16 | Claude: building       | CPU: 72.0°C GPU: 68.0°C Fan: 1450RPM GPU Power: 265W
```

**Example Integration in tmux Monitor:**

```bash
#!/bin/bash
# Enhanced tmux monitoring with thermal protection

source /path/to/claude-tools-monitor/integrations/power_integration.py

while true; do
    # Monitor Claude activity
    monitor_claude_sessions

    # Check thermal status
    if should_throttle_claude; then
        echo "🚨 THERMAL WARNING: Consider pausing Claude"
        notify-send "Claude Thermal Warning" "CPU temperature critical"
    fi

    sleep 5
done
```

---

### 3. Unified Monitoring Dashboard

Combined monitoring dashboard showing all system metrics in one view.

**Features:**
- 🎯 Unified view of PowerManagement + claude-tools-monitor
- 📊 Real-time system overview
- 🌡️ Temperature monitoring
- 💨 Fan status
- ⚡ Power consumption
- 🤖 Claude activity status
- 🔄 Auto-refresh capability

**Installation:**

```bash
# Already included in PowerManagement
bash integrations/unified_monitor.sh
```

**Usage:**

**Interactive Mode:**
```bash
# Launch interactive dashboard
bash integrations/unified_monitor.sh
```

**dmenu Mode:**
```bash
# Show menu options
bash integrations/unified_monitor.sh --dmenu | dmenu -p "Dashboard:"

# Direct action
bash integrations/unified_monitor.sh "📊 View Full Status"
```

**Available Commands:**

| Command | Description |
|---------|-------------|
| `📊 View Full Status` | Comprehensive system overview |
| `🔄 Refresh Dashboard` | Reload all metrics |
| `🌡️ Temperature Details` | All temperature sensors |
| `💨 Fan Control` | Fan management |
| `🎮 GPU Details` | GPU metrics |
| `⚡ Power Profiles` | Switch power mode |
| `📈 Start Monitoring Service` | Launch monitoring daemon |
| `🛑 Stop Monitoring Service` | Stop monitoring daemon |

**Dashboard Output Example:**

```
============================================
  🎯 Unified System Dashboard
============================================

🖥️  SYSTEM OVERVIEW
  Power Profile: ⚖️ Balanced
  Thermal Status: ✅ GOOD

🌡️  TEMPERATURE
  CPU: 45.0°C
  GPU: 62.0°C

💨 FANS
  CPU Fan: 1245 RPM

⚡ POWER
  CPU: 45.2W
  GPU: 245.0W

🤖 CLAUDE MONITOR
  Status: Running
  Activity: code generation

============================================
```

**Integration with MyMenu:**

```bash
# Add to MyMenu for quick access
echo "🎯 System Dashboard" >> MyMenu/dmenu-launcher.sh
# Handler:
bash /path/to/PowerManagement/integrations/unified_monitor.sh --dmenu
```

---

## 🛠️ Advanced Integration Scenarios

### Scenario 1: Automated Thermal Management During AI Sessions

**Goal:** Automatically adjust fan speeds when Claude is active

```bash
#!/bin/bash
# claude_thermal_guard.sh

POWER_MGMT="/home/user/PowerManagement"
export PYTHONPATH="$POWER_MGMT/src"

while true; do
    # Check if Claude is running
    if pgrep -f "claude" >/dev/null; then
        # Get CPU temperature
        cpu_temp=$(python3 -c "
from sensors.universal_sensor_detector import UniversalSensorDetector
detector = UniversalSensorDetector()
temps = detector.get_temperature_sensors()
for t in temps:
    if 'package' in t.label.lower():
        print(t.value)
        break
        ")

        # Adjust fans based on temp
        if (( $(echo "$cpu_temp > 75" | bc -l) )); then
            echo "🚨 High temp during Claude session: ${cpu_temp}°C"
            sudo python3 "$POWER_MGMT/src/sensors/fan_controller.py" set 0 75
        fi
    fi

    sleep 10
done
```

### Scenario 2: Power Profile Switcher Based on Workload

**Goal:** Automatically switch power profiles based on active applications

```bash
#!/bin/bash
# smart_power_switcher.sh

POWER_MGMT="/home/user/PowerManagement"

while true; do
    # Check active windows
    if xdotool getwindowfocus getwindowname | grep -i "game\|blender\|premiere"; then
        # Gaming/rendering - Performance mode
        bash "$POWER_MGMT/scripts/performance_manager.sh" performance
    elif xdotool getwindowfocus getwindowname | grep -i "battery\|unplugged"; then
        # On battery - Power save mode
        bash "$POWER_MGMT/scripts/performance_manager.sh" powersave
    else
        # Normal work - Balanced mode
        bash "$POWER_MGMT/scripts/performance_manager.sh" balanced
    fi

    sleep 60
done
```

### Scenario 3: Data Logging for Performance Analysis

**Goal:** Log all metrics for later analysis

```bash
#!/bin/bash
# metrics_logger.sh

POWER_MGMT="/home/user/PowerManagement"
LOG_DIR="$HOME/.power_metrics"
mkdir -p "$LOG_DIR"

# Start monitoring service
PYTHONPATH="$POWER_MGMT/src" python3 "$POWER_MGMT/src/services/monitoring_service.py" \
    --interval 5 \
    --log-dir "$LOG_DIR"

# Analyze later with:
# python3 -m json.tool ~/.power_metrics/power_monitoring.json
```

---

## 🔧 Configuration

### Environment Variables

```bash
# PowerManagement directory
export POWER_MGMT_DIR=/home/user/PowerManagement

# Add to PATH for shortcuts
export PATH="$HOME/.local/bin:$PATH"

# Python path for imports
export PYTHONPATH="$POWER_MGMT_DIR/src:$PYTHONPATH"
```

### Add to `.bashrc`:

```bash
# PowerManagement Integration
export POWER_MGMT_DIR=/home/user/PowerManagement
export PATH="$HOME/.local/bin:$PATH"
export PYTHONPATH="$POWER_MGMT_DIR/src:$PYTHONPATH"

# Aliases
alias pm-status='bash $POWER_MGMT_DIR/integrations/unified_monitor.sh "📊 View Full Status"'
alias pm-gpu='gpu-monitor'
alias pm-sensors='sensor-detector'
alias pm-fans='fan-control status'
alias pm-perf='power-manager performance'
alias pm-balanced='power-manager balanced'
alias pm-save='power-manager powersave'
```

---

## 📊 Integration Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   User Interface Layer                  │
│  ┌──────────┐  ┌───────────────┐  ┌─────────────────┐ │
│  │  MyMenu  │  │ Unified Dash  │  │  CLI Commands   │ │
│  │  (dmenu) │  │   (terminal)  │  │  (shortcuts)    │ │
│  └─────┬────┘  └───────┬───────┘  └────────┬────────┘ │
└────────┼───────────────┼──────────────────┼──────────┘
         │               │                   │
         └───────────────┴───────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
┌────────▼────────┐            ┌────────▼────────────┐
│ PowerManagement │            │ claude-tools-monitor│
│                 │            │                     │
│ • Sensors       │◄───────────┤ • Activity Log      │
│ • GPU Monitor   │            │ • Session Monitor   │
│ • Fan Control   │            │ • Thermal Guard     │
│ • Power Profiles│            │                     │
└─────────────────┘            └─────────────────────┘
         │
         │
┌────────▼─────────────────────────────────────────────┐
│              Hardware Abstraction Layer               │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │  sysfs   │  │lm-sensors│  │ GPU drivers      │  │
│  │ (hwmon)  │  │ (sensors)│  │ (nvidia/amd/i915)│  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Integration Not Working

**Check installation paths:**
```bash
echo $POWER_MGMT_DIR
ls -la $POWER_MGMT_DIR/integrations/
```

**Verify Python path:**
```bash
python3 -c "import sys; print('\n'.join(sys.path))"
```

**Test integration directly:**
```bash
# MyMenu integration
bash integrations/mymenu_integration.sh status

# Claude monitor integration
python3 claude-tools-monitor/integrations/power_integration.py

# Unified dashboard
bash integrations/unified_monitor.sh "📊 View Full Status"
```

### MyMenu Patch Failed

```bash
# Check backup exists
ls -la /path/to/MyMenu/dmenu-launcher.sh.backup*

# Manual restore
cp dmenu-launcher.sh.backup.YYYYMMDD_HHMMSS dmenu-launcher.sh

# Try manual integration instead
source /path/to/PowerManagement/integrations/mymenu_integration.sh
```

### Permissions Issues

```bash
# Add user to required groups
sudo usermod -aG gpio $USER
sudo usermod -aG i2c $USER

# Make scripts executable
chmod +x integrations/*.sh
```

---

## 📚 Related Documentation

- [SENSOR_MONITORING.md](SENSOR_MONITORING.md) - Sensor detection and fan control
- [UNIVERSAL_HARDWARE.md](UNIVERSAL_HARDWARE.md) - Hardware compatibility
- [INTEGRATION_PLAN.md](INTEGRATION_PLAN.md) - Integration roadmap
- [README.md](../README.md) - Main documentation

---

## 🎯 Future Integration Ideas

- **Polybar Module** - Show metrics in polybar
- **i3status Integration** - Display in i3 status bar
- **Conky Widget** - Real-time monitoring widget
- **Notification Daemon** - Desktop notifications for alerts
- **Web Dashboard** - Browser-based monitoring
- **Grafana Integration** - Professional metrics visualization
- **Home Assistant** - Smart home integration
- **Prometheus Exporter** - Metrics collection

---

## 💡 Contributing

Want to add integration for another tool? See [INTEGRATION_PLAN.md](INTEGRATION_PLAN.md) for guidelines.

**Integration Checklist:**
- [ ] Create integration script in `integrations/`
- [ ] Add documentation to this file
- [ ] Test on multiple systems
- [ ] Update [INTEGRATION_PLAN.md](INTEGRATION_PLAN.md)
- [ ] Add example usage
- [ ] Create troubleshooting section
