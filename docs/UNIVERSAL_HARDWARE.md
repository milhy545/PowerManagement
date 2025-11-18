# Universal Hardware Support

## 🌍 Overview

Version 3.0 introduces **universal hardware support**, making PowerManagement portable across different CPUs, GPUs, and system configurations. The system now automatically detects your hardware and adapts thermal thresholds, frequency ranges, and power management strategies accordingly.

## 🚀 What's New in V3.0

### ✅ **No More Hardcoded Paths**
- All scripts use dynamic path detection
- Works from any installation directory
- No user-specific paths like `/home/username/`

### 🖥️ **Universal CPU Support**
Previously: Only Intel Core 2 Quad Q9550
Now: Supports:
- **Intel**: Core 2, Nehalem, Sandy Bridge, Ivy Bridge, Haswell, Broadwell, Skylake+
- **AMD**: K8, K10, Bulldozer, Zen (Ryzen)
- **Old Hardware**: Special support for legacy CPUs (2006+)

### 🎮 **Universal GPU Support**
Previously: Only AMD Radeon RV710 at `/sys/class/drm/card1`
Now: Auto-detects:
- AMD GPUs (any card number)
- NVIDIA GPUs
- Intel integrated graphics
- Gracefully handles missing GPU

### 🌡️ **Adaptive Thermal Management**
- Thermal thresholds automatically adjusted based on CPU specs
- **Old CPUs** (Core 2): Max 85°C emergency threshold
- **Modern Intel**: Max 100°C emergency threshold
- **AMD Ryzen**: Max 95°C emergency threshold
- Percentile-based thresholds (65%, 75%, 85%, 95% of CPU max)

## 📊 Hardware Detection

The system automatically detects:

```bash
python3 src/hardware/hardware_detector.py
```

**Output Example:**
```
============================================================
🔍 HARDWARE DETECTION REPORT
============================================================

🖥️  CPU INFORMATION:
   Vendor: INTEL
   Model: Intel(R) Core(TM)2 Quad CPU Q9550 @ 2.83GHz
   Generation: core2
   Cores: 4
   Frequency: 1333-2833 MHz (current: 2833 MHz)
   MSR Support: ✅ Yes
   CPUFreq Support: ✅ Yes
   Thermal Max Safe: 85°C

🎮 GPU INFORMATION:
   Vendor: AMD
   Model: AMD Radeon RV710
   Device Path: /sys/class/drm/card1
   Power Profile Support: ✅ Yes
   Power Cap Support: ❌ No

🌡️  THERMAL INFORMATION:
   Thermal Zones: 1
   Current Temperature: 45°C
   Maximum Safe Temp: 85°C
```

## 🔧 Universal CPU Frequency Manager

### Automatic CPU Detection

The new universal manager automatically:
1. Detects your CPU model and vendor
2. Determines available frequency control methods
3. Calculates optimal frequencies for each power profile
4. Uses CPU-specific MSR multipliers (if available)

### Usage

```bash
# Show status with auto-detected settings
python3 src/frequency/universal_cpu_manager.py status

# Detect hardware
python3 src/frequency/universal_cpu_manager.py detect

# Set profile (works on ANY CPU)
python3 src/frequency/universal_cpu_manager.py profile performance
python3 src/frequency/universal_cpu_manager.py profile balanced
python3 src/frequency/universal_cpu_manager.py profile powersave
python3 src/frequency/universal_cpu_manager.py profile emergency
```

### Supported Control Methods

1. **cpufreq** (preferred for most systems)
   - Standard Linux cpufreq subsystem
   - Works with acpi-cpufreq driver

2. **intel_pstate** (modern Intel CPUs)
   - Built-in Intel P-state driver
   - Skylake and newer

3. **MSR** (legacy CPUs)
   - Direct Model Specific Register access
   - Core 2 Quad with known multipliers

4. **cpupower** (fallback)
   - Command-line utility
   - Universal but requires manual setup

## ⚙️ Configuration System

### Dynamic Configuration

The system now uses a centralized configuration that adapts to your hardware:

```python
from config.power_config import PowerConfig

config = PowerConfig()
config.print_config()
```

**Example Output:**
```
============================================================
⚙️  POWER MANAGEMENT CONFIGURATION
============================================================

📁 PATHS:
   Install Dir: /opt/PowerManagement
   Scripts Dir: /opt/PowerManagement/scripts
   Config File: /etc/power-management/config.json

🌡️  THERMAL CONFIG:
   Comfort:    < 55°C  (65% of max safe)
   Warning:    63°C    (75% of max safe)
   Critical:   72°C    (85% of max safe)
   Emergency:  80°C    (95% of max safe)

⚡ FREQUENCY CONFIG:
   Range:       800-3500 MHz
   Performance: 3500 MHz
   Balanced:    2690 MHz
   Powersave:   2150 MHz
   Emergency:   800 MHz
```

### Configuration Locations

The system searches for config in this order:
1. `/etc/power-management/config.json` (system-wide)
2. `~/.config/power-management/config.json` (user-specific)
3. `./config/config.json` (local installation)

## 🔌 Installation Flexibility

### Install Anywhere

The refactored system works from any directory:

```bash
# Clone to any location
git clone https://github.com/milhy545/PowerManagement.git /opt/PowerManagement
cd /opt/PowerManagement

# Or to your home directory
git clone https://github.com/milhy545/PowerManagement.git ~/my-power-mgmt
cd ~/my-power-mgmt

# Scripts automatically detect their location
./scripts/performance_manager.sh status
```

### No Hardcoded Dependencies

**Before (V2.0):**
```bash
# ❌ Would fail on different systems
SCRIPT="/home/milhy777/performance_manager.sh"
```

**After (V3.0):**
```bash
# ✅ Works anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$INSTALL_DIR/scripts/performance_manager.sh"
```

## 🧪 Testing Universal Support

### Run Universal Tests

```bash
# Test all universal features
bash tests/test_universal_system.sh
```

**Test Coverage:**
- ✅ Hardware detection
- ✅ Configuration system
- ✅ Universal CPU manager
- ✅ Thermal manager adaptation
- ✅ Dynamic path resolution
- ✅ GPU auto-detection
- ✅ Hardcoded path removal verification

### Manual Testing

```bash
# 1. Test hardware detection
python3 src/hardware/hardware_detector.py

# 2. Test configuration
python3 src/config/power_config.py

# 3. Test CPU manager
python3 src/frequency/universal_cpu_manager.py status

# 4. Test performance manager
./scripts/performance_manager.sh status
```

## 📝 Migration from V2.0

### If You're Using Q9550

**Good news:** Everything still works! The system detects Q9550 and uses the original optimized settings.

### If You're Using Different Hardware

**V3.0 automatically:**
1. Detects your CPU model
2. Calculates safe frequency ranges
3. Sets appropriate thermal thresholds
4. Finds your GPU device path
5. Uses compatible control methods

**No manual configuration required!**

## 🎯 Hardware Compatibility Matrix

| CPU Family | Frequency Control | Thermal Mgmt | Status |
|------------|------------------|--------------|--------|
| Intel Core 2 (2006-2011) | MSR/cpufreq | ✅ 85°C max | Tested |
| Intel Core i (1st-5th gen) | cpufreq | ✅ 95°C max | Compatible |
| Intel Core i (6th+ gen) | intel_pstate | ✅ 100°C max | Compatible |
| AMD K8/K10 | cpufreq | ✅ 70°C max | Compatible |
| AMD Bulldozer | cpufreq | ✅ 75°C max | Compatible |
| AMD Zen/Ryzen | cpufreq | ✅ 95°C max | Compatible |

| GPU Vendor | Power Control | Auto-detect | Status |
|------------|---------------|-------------|--------|
| AMD | power_profile | ✅ Yes | Tested |
| NVIDIA | power_cap | ⚠️ Limited | Compatible |
| Intel iGPU | Basic | ✅ Yes | Compatible |

## 🚨 Limitations

### CI/GitHub Actions
In CI environments, hardware features are limited:
- No MSR access
- No cpufreq control
- No thermal zones
- System runs in simulation mode

### Root Requirements
Some features require root:
- MSR register access
- cpufreq governor changes
- GPU power profile changes

**Solution:** Use `sudo` or add user to appropriate groups.

## 📚 Architecture

### New Modules

1. **hardware/hardware_detector.py**
   - Universal CPU detection
   - GPU detection
   - Thermal capability detection

2. **config/power_config.py**
   - Dynamic path resolution
   - Hardware-adaptive configuration
   - Cross-platform settings

3. **frequency/universal_cpu_manager.py**
   - Multi-vendor CPU support
   - Automatic method selection
   - Adaptive frequency profiles

### Refactored Components

- `daemons/custom-power-profiles-daemon.py` - Uses PowerConfig
- `scripts/performance_manager.sh` - Auto-detects GPU, uses universal CPU manager
- `scripts/ai_process_manager.sh` - Dynamic path resolution
- `scripts/smart_thermal_manager.py` - Adaptive thermal thresholds

## 🛠️ Troubleshooting

### Hardware Not Detected

```bash
# Check detection
python3 src/hardware/hardware_detector.py

# If CPU vendor is UNKNOWN
# -> May be running in VM or limited environment
# -> System will use conservative defaults

# If GPU not found
# -> Power management will skip GPU features
# -> Core CPU/thermal management still works
```

### Frequency Control Not Working

```bash
# Check available methods
python3 src/frequency/universal_cpu_manager.py status

# If control method is "none":
# 1. Check if cpufreq is available: ls /sys/devices/system/cpu/cpu0/cpufreq
# 2. Check if MSR module loaded: lsmod | grep msr
# 3. Try loading MSR: sudo modprobe msr
# 4. Install cpupower: sudo apt install linux-tools-generic
```

### Path Issues

```bash
# If scripts can't find modules:
# 1. Check installation directory
echo $INSTALL_DIR

# 2. Verify Python path
python3 -c "import sys; print(sys.path)"

# 3. Test import
python3 -c "import sys; sys.path.insert(0, 'src'); from hardware.hardware_detector import HardwareDetector"
```

## 📖 Additional Resources

- [README.md](../README.md) - Main documentation
- [PORTFOLIO.md](../PORTFOLIO.md) - Technical deep-dive
- [POWER_MODES_TABLE.md](POWER_MODES_TABLE.md) - Power mode reference
- [Test Suite](../tests/) - Comprehensive tests

## 💡 Contributing

To add support for new hardware:

1. Update `hardware_detector.py` with new CPU/GPU detection
2. Add MSR multipliers (if applicable) to `universal_cpu_manager.py`
3. Test on your hardware
4. Submit pull request with hardware specs

## 🎉 Summary

**Version 3.0 transforms PowerManagement from a single-system tool into a universal power management solution.**

- ✅ Works on old and new hardware
- ✅ No configuration required
- ✅ Portable across systems
- ✅ Gracefully handles missing features
- ✅ Maintains backward compatibility

**Install once, run anywhere!**
