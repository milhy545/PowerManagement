<!--
   FORAI Analytics Headers - 2025-07-20T03:18:21.414980
   Agent: claude-code
   Session: unified_20250720_031821_807589
   Context: Systematic FORAI header application - Markdown files batch
   File: README.md
   Auto-tracking: Enabled
   Memory-integrated: True
-->

# 🚀 Linux Power Management Suite

**Professional power management tools for Linux systems with safety-first design.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Ready](https://img.shields.io/badge/GitHub-Ready-green.svg)](https://github.com)
[![Tested](https://img.shields.io/badge/Tested-Passing-brightgreen.svg)](tests/)

## 🎯 Features

### Core Power Management
- **🔥 Performance Mode** - Full CPU (2.83GHz) + GPU power for gaming/work
- **⚖️ Balanced Mode** - Smart power management (2.16GHz) for daily use  
- **🔋 Power Save Mode** - Low power (1.66GHz) for battery/stability
- **🚨 Emergency Mode** - Emergency frequency (1.33GHz) & system recovery

### Advanced Features
- **⚡ CPU Frequency Control** - MSR-based frequency scaling for Core 2 Quad Q9550
- **🌡️ Thermal Management** - Progressive thermal response (65°C → 70°C → 80°C → emergency)
- **🤖 AI Process Management** - Thermal-protected AI workload management
- **🎯 Core Affinity** - Process-specific CPU core assignment
- **🛡️ Safety First** - Process monitoring, timeouts, error handling
- **📊 System Monitoring** - Real-time CPU, GPU, memory, temperature tracking

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/linux-power-management.git
cd linux-power-management

# Install (requires sudo)
sudo ./scripts/install.sh

# Test installation
./scripts/performance_manager.sh test

# Set performance mode
./scripts/performance_manager.sh performance

# Test CPU frequency control
python3 src/frequency/cpu_frequency_manager.py status
```

## 📋 Usage

### Performance Manager
```bash
# Performance profiles
./scripts/performance_manager.sh performance  # Max power
./scripts/performance_manager.sh balanced     # Balanced  
./scripts/performance_manager.sh powersave    # Power save
./scripts/performance_manager.sh emergency    # Emergency

# System info
./scripts/performance_manager.sh status       # Current status
./scripts/performance_manager.sh log          # View logs
./scripts/performance_manager.sh test         # Dry run test
```

### CPU Frequency Control
```bash
# Check current frequency and thermal profiles
python3 src/frequency/cpu_frequency_manager.py status

# Apply thermal profiles
python3 src/frequency/cpu_frequency_manager.py thermal performance  # 2.83GHz
python3 src/frequency/cpu_frequency_manager.py thermal balanced     # 2.16GHz  
python3 src/frequency/cpu_frequency_manager.py thermal power_save   # 1.66GHz
python3 src/frequency/cpu_frequency_manager.py thermal emergency    # 1.33GHz

# Set specific frequency
python3 src/frequency/cpu_frequency_manager.py set 1666
```

### AI Process Manager
```bash
# AI process control
./scripts/ai_process_manager.sh show         # Show AI processes
./scripts/ai_process_manager.sh optimize     # Optimize performance
./scripts/ai_process_manager.sh emergency    # Emergency stop

# AI workload testing
python3 examples/ai_workloads/final_mycoder_test.py        # Thermal-protected AI test
python3 examples/ai_workloads/ultra_safe_mycoder.py        # Ultra-safe AI demo
```

## 🛡️ Safety Features

- **Process Limit Monitoring** - Prevents fork bombs (max 10 instances)
- **Timeout Protection** - All operations timeout after 5-8 seconds
- **Error Handling** - Graceful failure with logging
- **Dry Run Mode** - Test changes before applying
- **Emergency Recovery** - Blackscreen prevention tools
- **Permission Checks** - Proper sudo handling

## 📊 System Requirements

- **OS**: Linux (Ubuntu/Debian/Fedora/Arch)
- **Kernel**: 5.0+ (power management support)
- **Dependencies**: `powerprofilesctl`, `systemd`
- **Permissions**: sudo access for power management
- **Hardware**: AMD/Intel CPU, optional GPU support

## 📁 Project Structure

```
linux-power-management/
├── scripts/
│   ├── performance_manager.sh    # Main power control
│   ├── ai_process_manager.sh     # AI process management
│   ├── emergency_cleanup.sh      # Emergency recovery
│   └── system_monitor.sh         # System monitoring
├── config/
│   └── power_profiles.conf       # Configuration
├── tests/
│   └── test_suite.sh            # Test automation
├── docs/
│   ├── INSTALL.md               # Installation guide
│   ├── USAGE.md                 # Usage examples
│   └── TROUBLESHOOTING.md       # Problem solving
└── .github/
    └── workflows/
        └── test.yml             # CI/CD pipeline
```

## 🔧 Configuration

Edit `config/power_profiles.conf`:
```bash
# Maximum allowed processes
MAX_PROCESSES=10

# Default timeouts (seconds)
POWER_TIMEOUT=8
GPU_TIMEOUT=3
EMERGENCY_TIMEOUT=5

# Log file location
LOG_FILE="/tmp/performance_manager.log"
```

## 🧪 Testing

```bash
# Run test suite
./tests/test_suite.sh

# Individual tests
./scripts/performance_manager.sh test
./scripts/ai_process_manager.sh show
```

## 🚨 Emergency Recovery

If system becomes unresponsive:
```bash
# Magic SysRq sequence (hardware level)
Alt + SysRq + R,E,I,S,U,B

# SSH recovery
ssh user@system './scripts/emergency_cleanup.sh'

# Emergency power save
./scripts/performance_manager.sh emergency
```

## 📈 Performance Results

**Before Power Management:**
- Load: 4.43, Memory: 5.0Gi, CPU: Variable
- Graphics freezes, blackscreen issues

**After Power Management:**
- Load: 0.46 (90% improvement)
- Memory: 2.6Gi (48% reduction)  
- Stable graphics, no blackscreens
- Full 2.83GHz CPU available on demand

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

Use at your own risk. Always test in safe environments first. This software modifies system power settings and can affect system stability.

## 🙏 Acknowledgments

- Built with Claude AI assistance
- Tested on Intel Core2 Quad Q9550 + AMD Radeon RV710
- Thanks to the Linux community for power management tools

---
**Made with ❤️ for the Linux community**