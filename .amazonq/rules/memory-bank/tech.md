# Linux Power Management Suite - Technology Stack

## Programming Languages

### Bash Shell (Primary)
- **Version**: Bash 4.0+
- **Usage**: Main executable scripts, system integration, process management
- **Key Scripts**: performance_manager.sh, ai_process_manager.sh, EMERGENCY_CLEANUP.sh
- **Rationale**: Direct system access, excellent for system administration tasks

### Python 3 (Secondary)
- **Version**: Python 3.6+
- **Usage**: CPU frequency control, thermal management, complex logic
- **Key Modules**: cpu_frequency_manager.py, smart_thermal_manager.py
- **Rationale**: Better structured code for complex algorithms, easier testing

## Core Dependencies

### System Tools
- **powerprofilesctl**: System power profile management
  - Controls performance/balanced/power-saver modes
  - Integration with system power management

- **systemd**: Service management and daemon control
  - Service unit files in configs/
  - Daemon lifecycle management

- **cpufreq-utils**: CPU frequency scaling utilities
  - Governor control
  - Frequency information

### Hardware Access
- **MSR (Model Specific Registers)**: Direct CPU frequency control
  - Requires msr kernel module
  - Low-level CPU frequency manipulation
  - Used by cpu_frequency_manager.py

- **sysfs**: GPU and thermal sensor access
  - /sys/class/drm/card*/device/power_profile (GPU)
  - /sys/class/thermal/thermal_zone* (temperatures)
  - /sys/devices/system/cpu/cpu*/cpufreq/ (CPU frequency)

### Process Management
- **renice**: Process priority adjustment
  - AI process priority control
  - Nice values: -20 (highest) to +19 (lowest)

- **pkill/pgrep**: Process management
  - Process discovery and termination
  - Used in emergency cleanup

- **cpulimit**: CPU usage limiting (optional)
  - Process CPU throttling
  - Removed during performance mode

## Build System

### No Build Required
This is a script-based project with no compilation step:
- Shell scripts are directly executable
- Python scripts run via interpreter
- No package building or compilation needed

### Installation
```bash
# Manual installation
sudo cp scripts/*.sh /usr/local/bin/
sudo cp configs/*.service /etc/systemd/system/
sudo systemctl daemon-reload

# Service enablement
sudo systemctl enable custom-power-profiles-daemon.service
sudo systemctl start custom-power-profiles-daemon.service
```

## Development Commands

### Testing
```bash
# Run full test suite
./tests/test_suite.sh

# Quick validation
./tests/quick_test.sh

# CPU frequency testing
./tests/test_cpu_frequency.sh

# Thermal management testing
./tests/test_thermal_management.sh

# CI compatibility testing
./tests/test_ci_compatibility.sh
```

### Usage
```bash
# Power mode control
./scripts/performance_manager.sh [performance|balanced|powersave|emergency]
./scripts/performance_manager.sh status
./scripts/performance_manager.sh test  # Dry run

# CPU frequency control
python3 src/frequency/cpu_frequency_manager.py status
python3 src/frequency/cpu_frequency_manager.py thermal [performance|balanced|power_save|emergency]
python3 src/frequency/cpu_frequency_manager.py set <frequency_mhz>

# AI process management
./scripts/ai_process_manager.sh [show|optimize|emergency]

# Thermal management
python3 scripts/smart_thermal_manager.py

# Emergency recovery
./scripts/EMERGENCY_CLEANUP.sh
```

### Monitoring
```bash
# System status
./scripts/performance_manager.sh status

# View logs
./scripts/performance_manager.sh log
tail -f /tmp/performance_manager.log

# AI process monitoring
./scripts/ai_process_manager.sh show
```

## Runtime Requirements

### Kernel Modules
- **msr**: Model Specific Register access
  ```bash
  sudo modprobe msr
  ```

- **cpufreq**: CPU frequency scaling
  - Usually built into kernel

### Permissions
- **sudo access**: Required for power management operations
- **MSR access**: Requires root for CPU frequency control
- **sysfs write**: Requires root for GPU power profiles

### System Services
- **systemd**: Service management
- **dbus**: Inter-process communication (for KDE integration)
- **power-profiles-daemon**: System power profile daemon (replaced by custom version)

## Hardware Support

### CPU
- **Intel**: Core 2 Quad Q9550 (tested), modern Intel CPUs
- **AMD**: Supported via standard cpufreq interface
- **Frequency Range**: 1.33GHz - 2.83GHz (Q9550 specific)

### GPU
- **AMD**: Radeon RV710 (tested), modern AMD GPUs
- **Intel**: Integrated graphics (untested)
- **NVIDIA**: Limited support (untested)

### Thermal Sensors
- **CPU**: /sys/class/thermal/thermal_zone*
- **GPU**: GPU-specific thermal interfaces
- **Thresholds**: 65°C → 70°C → 80°C → emergency

## Configuration Files

### Service Configurations
- **configs/custom-power-profiles-daemon.service**: Custom daemon
- **configs/gpu-monitor.service**: GPU monitoring
- **configs/auto-recovery-agent.service**: Auto-recovery

### Runtime Configuration
- **Log File**: /tmp/performance_manager.log
- **State Files**: /tmp/*.state (planned)
- **Config File**: config/power_profiles.conf (planned)

## CI/CD Integration

### GitHub Actions
- **Workflow**: .github/workflows/test.yml
- **Tests**: Automated test suite execution
- **Validation**: Script syntax checking, dry-run testing

### Test Environment
- **OS**: Linux (Ubuntu/Debian preferred)
- **Kernel**: 5.0+
- **Dependencies**: Installed via package manager

## Version Control
- **Git**: Source control
- **GitHub**: Repository hosting
- **License**: MIT License
