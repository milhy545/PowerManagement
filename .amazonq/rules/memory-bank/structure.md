# Linux Power Management Suite - Project Structure

## Directory Organization

```
PowerManagement/
├── scripts/              # Main executable scripts
├── src/                  # Python source modules
├── daemons/              # Systemd daemon services
├── core/                 # Core power control utilities
├── examples/             # Example implementations and demos
├── tests/                # Test suites and validation
├── configs/              # Systemd service configurations
├── docs/                 # Documentation
├── archive/              # Legacy code and deprecated features
└── .github/              # CI/CD workflows
```

## Core Components

### scripts/ - Main Executable Scripts
Primary user-facing scripts for power management operations:

- **performance_manager.sh**: Main power control interface
  - Manages four power modes (performance/balanced/powersave/emergency)
  - Integrates CPU governor, GPU profiles, and system settings
  - Includes process monitoring and timeout protection

- **smart_thermal_manager.py**: Intelligent thermal management
  - Progressive thermal response system
  - Temperature monitoring and automatic throttling
  - Thermal profile management

- **ai_process_manager.sh**: AI workload management
  - Process priority control for AI applications
  - Thermal-protected AI execution
  - Emergency AI process termination

- **EMERGENCY_CLEANUP.sh**: System recovery tool
  - Process explosion cleanup
  - Memory clearing and cache dropping
  - Emergency power profile restoration

- **temperature_guardian.sh**: Temperature monitoring daemon
  - Continuous thermal monitoring
  - Automatic emergency response
  - Thermal threshold enforcement

### src/ - Python Source Modules
Core Python implementations for low-level control:

- **src/frequency/cpu_frequency_manager.py**: CPU frequency control
  - MSR-based frequency scaling
  - Thermal profile management (performance/balanced/power_save/emergency)
  - Direct CPU frequency manipulation (1.33GHz - 2.83GHz)

### daemons/ - Systemd Services
Background services for automated power management:

- **custom-power-profiles-daemon.py**: Custom power profile daemon
  - Replaces system power-profiles-daemon
  - Provides enhanced power profile control
  - Integrates with systemd

### core/ - Core Utilities
Fundamental power control tools:

- **custom-powerprofilesctl**: Custom powerprofilesctl wrapper
  - Enhanced power profile control
  - Integration with custom daemon

- **master-power-controller.sh**: Master control script
  - Coordinates all power management components
  - Centralized configuration management

- **kde-power-profile-enabler.sh**: KDE integration
  - KDE Plasma power widget integration
  - Desktop environment compatibility

### examples/ - Example Implementations
Demonstration scripts and AI workload examples:

- **examples/ai_workloads/**: AI process examples
  - final_mycoder_test.py: Thermal-protected AI testing
  - ultra_safe_mycoder.py: Ultra-safe AI demonstration
  - streaming_mycoder.py: Streaming AI workload
  - real_mycoder_safe.py: Production-safe AI implementation
  - interactive_mycoder.py: Interactive AI demo

### tests/ - Test Suites
Comprehensive testing infrastructure:

- **test_suite.sh**: Main test orchestrator
- **test_cpu_frequency.sh**: CPU frequency validation
- **test_thermal_management.sh**: Thermal system testing
- **quick_test.sh**: Rapid validation suite
- **test_ci_compatibility.sh**: CI/CD integration tests

### configs/ - Service Configurations
Systemd service unit files:

- **custom-power-profiles-daemon.service**: Custom daemon service
- **gpu-monitor.service**: GPU monitoring service
- **auto-recovery-agent.service**: Automatic recovery service

### docs/ - Documentation
Technical documentation and guides:

- **POWER_MODES_TABLE.md**: Detailed power mode specifications
- Additional documentation for installation, usage, troubleshooting

## Architectural Patterns

### Layered Architecture
1. **User Interface Layer**: Shell scripts (performance_manager.sh, ai_process_manager.sh)
2. **Control Layer**: Python modules (cpu_frequency_manager.py, smart_thermal_manager.py)
3. **System Layer**: Systemd daemons and core utilities
4. **Hardware Layer**: Direct MSR access, GPU control, thermal sensors

### Component Relationships
```
User Commands
    ↓
performance_manager.sh ←→ ai_process_manager.sh
    ↓                           ↓
cpu_frequency_manager.py ←→ smart_thermal_manager.py
    ↓                           ↓
MSR/sysfs/powerprofilesctl ←→ Temperature Sensors
    ↓                           ↓
Hardware (CPU/GPU)
```

### Safety Architecture
- **Process Monitoring**: All scripts check for duplicate instances
- **Timeout Protection**: Operations bounded by 5-8 second timeouts
- **Error Handling**: Graceful degradation with logging
- **Emergency Recovery**: Multiple layers of fallback mechanisms

### Integration Points
- **Systemd**: Service management and daemon integration
- **KDE Plasma**: Desktop environment power widget
- **powerprofilesctl**: System power profile interface
- **MSR**: Direct CPU frequency control
- **sysfs**: GPU power profile management
- **Temperature Sensors**: Thermal monitoring via /sys/class/thermal

## Configuration Management
- **Centralized Config**: config/power_profiles.conf (planned)
- **Service Configs**: configs/*.service files
- **Runtime State**: /tmp/performance_manager.log
- **System Integration**: /etc/systemd/system/ for services
