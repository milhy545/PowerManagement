# Changelog

All notable changes to PowerManagement will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2025-11-18

### Added - Major Feature Update

#### GPU Monitoring & Control
- **Universal GPU Monitor** - Real-time GPU monitoring for NVIDIA, AMD, and Intel GPUs
- **GPU Temperature** - Track GPU core temperature with alerts
- **GPU Fan Control** - Control NVIDIA and AMD GPU fan speeds
- **GPU Power Monitoring** - Track power consumption and limits
- **Multi-GPU Support** - Monitor and control multiple GPUs simultaneously

#### Advanced Sensor Detection
- **Universal Sensor Detector** - Comprehensive sensor detection across all hardware
- **Multiple Detection Methods** - lm-sensors, sysfs hwmon, thermal zones, ACPI
- **Atypical Hardware Support** - Works on all-in-one PCs (Acer, Dell, etc.)
- **40+ Sensor Types** - Temperature, fan, voltage, power, current sensors
- **Robust Detection** - Graceful fallbacks for difficult motherboards

#### Fan Control System
- **PWM Fan Control** - Direct hardware fan control via Linux sysfs
- **Auto Fan Mode** - Temperature-based automatic fan adjustment
- **Manual Control** - Set specific fan speeds (0-100%)
- **Multi-Fan Support** - Control CPU, case, and GPU fans independently
- **Safety Limits** - Minimum speed enforcement to prevent overheating

#### Professional Monitoring Service
- **Real-time Monitoring Daemon** - Continuous background monitoring
- **Thermal Alerts** - Automatic alerts on critical temperatures
- **JSON Logging** - Machine-readable metrics logging
- **Configurable Intervals** - Adjust monitoring frequency
- **Service Management** - Easy start/stop/status commands

#### Project Integrations
- **MyMenu Integration** - dmenu launcher interface with automatic patching
- **claude-tools-monitor Integration** - Thermal-aware AI session monitoring
- **Unified Dashboard** - Combined monitoring across all projects
- **Integration Documentation** - Complete integration guides

### Enhanced
- **Documentation** - Added SENSOR_MONITORING.md with comprehensive sensor guide
- **Documentation** - Added INTEGRATIONS.md with integration examples
- **Documentation** - Added INTEGRATION_PLAN.md with roadmap
- **Test Suite** - Comprehensive 40+ test suite for all new features
- **README** - Added integrations section with quick start guides

### Fixed
- Sensor detection on atypical motherboards
- All-in-one PC compatibility issues
- Missing sensor values handled gracefully

## [3.0.0] - 2025-11-17

### Added - Universal Hardware Support

#### CPU Support
- **Universal CPU Detection** - Auto-detect Intel and AMD CPUs across generations
- **Intel Support** - Core 2 Quad, Nehalem, Sandy Bridge, Haswell, Skylake+
- **AMD Support** - K8 (Phenom), K10, Bulldozer/Piledriver, Zen (Ryzen)
- **Adaptive Thermal Management** - CPU-specific temperature thresholds
- **Frequency Scaling** - Multi-method frequency control (cpufreq, MSR, cpupower)

#### Hardware Detection
- **Hardware Detector** - Automatic CPU/GPU vendor and generation detection
- **Thermal Profiles** - CPU-specific thermal limits and safe ranges
- **Feature Detection** - MSR support, turbo boost, P-states

#### Configuration System
- **Dynamic Path Resolution** - No more hardcoded paths
- **Power Configuration** - Centralized configuration management
- **Portable Installation** - Install anywhere, works from any directory

### Changed
- **Removed Hardcoded Paths** - All `/home/milhy777/` paths replaced with dynamic detection
- **Universal GPU Detection** - Auto-detect AMD, NVIDIA, Intel GPUs
- **Refactored Daemon** - Uses new configuration system
- **Refactored Scripts** - All scripts use dynamic paths

### Fixed
- Hardcoded path issues in daemon (`custom-power-profiles-daemon.py`)
- Hardcoded path in `performance_manager.sh` (line 305-307)
- Hardcoded path in `ai_process_manager.sh` (line 30)
- GPU card hardcoded to card1 - now auto-detects card0-9
- Dead code removed (claude --agent calls, lines 253-266)

### Enhanced
- **Documentation** - Added UNIVERSAL_HARDWARE.md with compatibility guide
- **Documentation** - Updated README with v3.0 features
- **Installation** - One-click install script
- **Testing** - Comprehensive test suite

## [2.0.0] - Previous Version

### Features
- Basic power profile management (Performance, Balanced, Power Save, Emergency)
- CPU frequency control via MSR registers
- GPU power profile control
- Thermal monitoring and response
- AI process management with thermal protection
- D-Bus power profiles daemon
- System monitoring scripts

### Hardware
- Optimized for Intel Core 2 Quad Q9550
- Basic AMD/NVIDIA GPU support

## [1.0.0] - Initial Release

### Features
- Manual CPU frequency control
- Basic power profiles
- Simple GPU control
- Emergency cleanup tools

---

## Version Guidelines

### Major Version (X.0.0)
- Breaking changes to API or configuration
- Major architectural changes
- Removal of deprecated features

### Minor Version (0.X.0)
- New features (backward compatible)
- New hardware support
- New integrations

### Patch Version (0.0.X)
- Bug fixes
- Documentation updates
- Performance improvements

---

## Upgrade Notes

### Upgrading to 3.1.0
- No breaking changes
- New optional features (GPU monitoring, fan control, monitoring service)
- Existing configurations remain compatible
- New integrations are opt-in

### Upgrading to 3.0.0
- **Breaking**: Hardcoded paths removed - reinstall required
- **Breaking**: Old configuration files may need updates
- **Migration**: Run `install.sh` to update paths
- **Benefit**: Works on any hardware, install anywhere

---

## Future Roadmap

See [INTEGRATION_PLAN.md](docs/INTEGRATION_PLAN.md) for detailed roadmap.

### Planned Features
- Web-based dashboard
- Prometheus exporter for metrics
- Systemd unit files for monitoring service
- Polybar/i3status integration
- Home Assistant integration
- More GPU vendor support (PowerVR, Mali, etc.)

### Under Consideration
- Laptop battery optimization profiles
- Network-based remote monitoring
- Historical metrics database
- Machine learning thermal predictions
- Custom fan curves per application
## [2.0.0] - 2025-01-20
- Installation script
- Configuration file
- Complete documentation
- CI fixes
- Type hints
