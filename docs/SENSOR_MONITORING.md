# Advanced Sensor Monitoring & Fan Control

## 🌡️ Overview

Version 3.1 adds **professional-grade sensor monitoring and fan control** capabilities:

- 🎮 **GPU Monitoring** - NVIDIA, AMD, Intel (temperature, fan speed, power)
- 🔍 **Universal Sensor Detection** - ALL system sensors (even atypical motherboards)
- 💨 **Fan Control** - CPU & GPU fans (PWM control, automatic adjustment)
- 📊 **Monitoring Service** - Real-time daemon with auto fan control & alerts
- 🏭 **All-in-One PC Support** - Works on difficult configurations (Acer, Dell AIO, etc.)

## 🎮 GPU Monitoring

### Supported GPUs

- **NVIDIA** - via nvidia-smi (GeForce, Quadro, Tesla)
- **AMD** - via sysfs hwmon (Radeon, RX series)
- **Intel** - via sysfs (integrated graphics)

### Features

```python
from sensors.gpu_monitor import UniversalGPUMonitor

monitor = UniversalGPUMonitor()

# Get all GPU metrics
for metrics in monitor.get_all_metrics():
    print(f"GPU: {metrics.name}")
    print(f"  Temperature: {metrics.temperature}°C")
    print(f"  Fan Speed: {metrics.fan_speed}%")
    print(f"  Fan RPM: {metrics.fan_rpm}")
    print(f"  Power: {metrics.power_usage}W / {metrics.power_limit}W")
    print(f"  Utilization: {metrics.utilization}%")
    print(f"  Memory: {metrics.memory_used}MB / {metrics.memory_total}MB")

# Generate report
print(monitor.generate_report())
```

**Output Example:**
```
============================================================
🎮 GPU MONITORING REPORT
============================================================

📊 Detected GPUs: 2

GPU #0: NVIDIA GeForce RTX 3080 (NVIDIA)
  🌡️  Temperature: 62°C
  💨 Fan: 45% (1850 RPM)
  ⚡ Power: 245W / 320W
  📊 Utilization: 87%
  💾 Memory: 8245MB / 10240MB (80%)

GPU #1: AMD Radeon RX 6800 (AMD)
  🌡️  Temperature: 58°C
  💨 Fan: 40% (1650 RPM)
  ⚡ Power: 180W

============================================================
```

### Command Line

```bash
# Show all GPU metrics
python3 src/sensors/gpu_monitor.py
```

## 🔍 Universal Sensor Detection

Detects **ALL** sensors in your system:

- 🌡️ **Temperature** - CPU, GPU, motherboard, drives
- 💨 **Fans** - All fan sensors with RPM readings
- ⚡ **Voltage** - CPU, RAM, motherboard voltages
- 🔌 **Power** - Package power, GPU power
- 🔋 **Battery** - Voltage, current, power, energy (laptops)

### Features

```python
from sensors.universal_sensor_detector import UniversalSensorDetector

detector = UniversalSensorDetector()

# Get all temperature sensors
temps = detector.get_temperature_sensors()
for sensor in temps:
    print(f"{sensor.label}: {sensor.value}°C [{sensor.chip}]")

# Get all fan sensors
fans = detector.get_fan_sensors()
for sensor in fans:
    print(f"{sensor.label}: {sensor.value} RPM [{sensor.chip}]")

# Generate comprehensive report
print(detector.generate_report())
```

**Output Example:**
```
======================================================================
🔍 UNIVERSAL SENSOR DETECTION REPORT
======================================================================

📊 Total Sensors Detected: 42

🌡️  TEMPERATURE SENSORS (12)
----------------------------------------------------------------------
  • Package id 0                 : 45.0 °C      [coretemp-isa-0000]
  • Core 0                       : 42.0 °C      [coretemp-isa-0000]
  • Core 1                       : 43.0 °C      [coretemp-isa-0000]
  • Core 2                       : 44.0 °C      [coretemp-isa-0000]
  • Core 3                       : 45.0 °C      [coretemp-isa-0000]
  • edge                         : 62.0 °C      [amdgpu-pci-0300]
  • junction                     : 68.0 °C      [amdgpu-pci-0300]
  • mem                          : 56.0 °C      [amdgpu-pci-0300]
  • Motherboard                  : 38.0 °C      [nct6775-isa-0290]
  • CPU                          : 45.0 °C      [nct6775-isa-0290]
  • SATA 1                       : 35.0 °C      [drivetemp-scsi-0-0]
  • SATA 2                       : 36.0 °C      [drivetemp-scsi-1-0]

💨 FAN SENSORS (6)
----------------------------------------------------------------------
  • CPU Fan                      : 1245 RPM     [nct6775-isa-0290]
  • System Fan 1                 : 865 RPM      [nct6775-isa-0290]
  • System Fan 2                 : 920 RPM      [nct6775-isa-0290]
  • GPU Fan                      : 1850 RPM     [amdgpu-pci-0300]
  • PSU Fan                      : 450 RPM      [corsairpsu-hid-3-2]
  • AIO Pump                     : 2400 RPM     [nct6775-isa-0290]

⚡ VOLTAGE SENSORS (8)
----------------------------------------------------------------------
  • Vcore                        : 1.2 V        [nct6775-isa-0290]
  • +12V                         : 12.1 V       [nct6775-isa-0290]
  • +5V                          : 5.0 V        [nct6775-isa-0290]
  • +3.3V                        : 3.3 V        [nct6775-isa-0290]
  • VDDCR_SOC                    : 0.9 V        [k10temp-pci-00c3]
  • Vddq                         : 1.35 V       [nct6775-isa-0290]

🔌 POWER SENSORS (4)
----------------------------------------------------------------------
  • Package                      : 45.2 W       [coretemp-isa-0000]
  • GPU                          : 245.0 W      [amdgpu-pci-0300]
  • PSU Input                    : 385.0 W      [corsairpsu-hid-3-2]
  • PSU Output                   : 325.0 W      [corsairpsu-hid-3-2]

======================================================================
```

### Command Line

```bash
# Detect all sensors
python3 src/sensors/universal_sensor_detector.py
```

## 💨 Fan Control

Control CPU and GPU fans programmatically.

### Supported Methods

1. **PWM Control** (Linux sysfs) - CPU & case fans
2. **NVIDIA** (nvidia-settings) - NVIDIA GPU fans
3. **AMD** (sysfs hwmon) - AMD GPU fans

### Features

```python
from sensors.fan_controller import UniversalFanController

controller = UniversalFanController()

# Show all controllable fans
print(controller.generate_report())

# Set CPU fan to 60%
controller.set_pwm_fan_speed(fan_index=0, percent=60)

# Set fan to automatic mode
controller.set_fan_auto(fan_index=0)

# Set NVIDIA GPU fan
controller.set_nvidia_gpu_fan(gpu_index=0, percent=50)

# Set NVIDIA GPU to auto
controller.set_nvidia_gpu_fan_auto(gpu_index=0)
```

**Output Example:**
```
======================================================================
💨 FAN CONTROLLER REPORT
======================================================================

🌀 PWM Fans: 3
----------------------------------------------------------------------
  [0] nct6775/pwm1
      Speed: 48% (122/255 PWM) - 1245 RPM
      Mode: auto
      Control: /sys/class/hwmon/hwmon1/pwm1

  [1] nct6775/pwm2
      Speed: 35% (89/255 PWM) - 865 RPM
      Mode: auto
      Control: /sys/class/hwmon/hwmon1/pwm2

  [2] nct6775/pwm5
      Speed: 95% (242/255 PWM) - 2400 RPM
      Mode: manual
      Control: /sys/class/hwmon/hwmon1/pwm5

🎮 GPU Fans: 2
----------------------------------------------------------------------
  • NVIDIA GeForce RTX 3080 Fan (NVIDIA)
  • AMD Radeon RX 6800 Fan (AMD)

======================================================================
```

### Command Line

```bash
# Show fan status
python3 src/sensors/fan_controller.py status

# Set fan speed (requires sudo)
sudo python3 src/sensors/fan_controller.py set 0 60

# Set fan to automatic
sudo python3 src/sensors/fan_controller.py auto 0

# Set NVIDIA GPU fan
python3 src/sensors/fan_controller.py nvidia 0 50
```

### ⚠️ Requirements

**For PWM fan control:**
- Root access (sudo)
- lm-sensors configured
- Fan control enabled in BIOS

**Setup:**
```bash
# Install lm-sensors
sudo apt install lm-sensors

# Detect sensors
sudo sensors-detect

# Enable fan control (if needed)
sudo pwmconfig
```

## 📊 Monitoring Service

Real-time monitoring daemon with **automatic fan control** and alerts.

### Features

- ✅ Real-time monitoring (CPU, GPU, fans, power)
- ✅ Automatic fan speed adjustment based on temperature
- ✅ Thermal alerts (warning, critical, emergency)
- ✅ JSON logging for data analysis
- ✅ Works on atypical systems (all-in-one PCs, laptops)

### Usage

```bash
# Start monitoring service (5 second interval)
python3 src/services/monitoring_service.py

# Custom interval (10 seconds)
python3 src/services/monitoring_service.py --interval 10

# Disable auto fan control
python3 src/services/monitoring_service.py --no-auto-fan

# Custom log directory
python3 src/services/monitoring_service.py --log-dir /var/log/power-mgmt
```

### Auto Fan Control

The service automatically adjusts fan speeds based on temperature:

| Temperature Range | Fan Speed | Action |
|------------------|-----------|--------|
| < Warning (65-75°C) | 30% | Low speed |
| Warning to Critical | 50% | Medium speed |
| Critical to Emergency | 75% | High speed |
| Emergency (>85°C) | 100% | Maximum cooling |

### Alerts

The service monitors and alerts on:

- ⚡ **Warning** - Temperature approaching safe limits
- ⚠️  **Critical** - Temperature in critical zone
- 🚨 **Emergency** - Temperature at dangerous levels

**Example Output:**
```
[2025-11-18 22:45:01] 🚀 Monitoring service started
[2025-11-18 22:45:01]    CPU: Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz
[2025-11-18 22:45:01]    Thermal limits: 70°C / 80°C / 95°C
[2025-11-18 22:45:01]    Interval: 5s
[2025-11-18 22:45:01]    Auto fan control: ✅ Enabled
[2025-11-18 22:45:06] 📊 CPU: 45.0°C | GPU: 62.0°C | Fan: 1245RPM
[2025-11-18 22:45:11] 📊 CPU: 46.0°C | GPU: 63.0°C | Fan: 1250RPM
[2025-11-18 22:45:16] 📊 CPU: 72.0°C | GPU: 68.0°C | Fan: 1450RPM
[2025-11-18 22:45:16] ⚡ CPU WARNING: 72.0°C
[2025-11-18 22:45:21] 📊 CPU: 75.0°C | GPU: 70.0°C | Fan: 1650RPM
[2025-11-18 22:45:21] ⚠️  CPU CRITICAL: 75.0°C
[2025-11-18 22:45:21] ⚠️  CRITICAL: Setting fans to 75%
```

### JSON Logging

All snapshots are logged to `/tmp/power_monitoring.json`:

```json
[
  {
    "timestamp": "2025-11-18T22:45:06",
    "cpu_temp": 45.0,
    "gpu_temp": 62.0,
    "cpu_fan_rpm": 1245,
    "gpu_fan_rpm": 1850,
    "gpu_power": 245,
    "cpu_power": 45.2,
    "voltages": {
      "Vcore": 1.2,
      "+12V": 12.1,
      "+5V": 5.0
    },
    "alerts": []
  }
]
```

## 🏭 All-in-One PC & Atypical System Support

The sensor system is designed to work on **difficult configurations**:

### Supported Scenarios

✅ **All-in-One PCs** (Acer, Dell, HP)
- Limited sensor access
- Non-standard fan configurations
- Embedded/integrated components

✅ **Laptops**
- Battery sensors
- Embedded controllers
- Hybrid graphics

✅ **Exotic Motherboards**
- Custom OEM boards
- Non-standard sensor chips
- Multiple hwmon devices

### How It Works

The system uses **multiple detection methods** with fallbacks:

1. **lm-sensors** - Primary method (most comprehensive)
2. **sysfs hwmon** - Direct hardware access
3. **thermal zones** - Kernel thermal subsystem
4. **ACPI** - Battery & power supply info
5. **GPU-specific** - nvidia-smi, AMD sysfs, Intel sysfs

**Example: All-in-One Acer System**
```
🔍 Detected on Acer Aspire C24-865:
  - CPU temp via acpi_thermal_rel
  - No dedicated CPU fan sensor (embedded in case)
  - GPU temp via i915 (Intel integrated)
  - System fan via embedded controller
  - Battery sensors (if model has battery)
```

## 🛠️ Troubleshooting

### No Sensors Detected

```bash
# Install lm-sensors
sudo apt install lm-sensors

# Detect sensors
sudo sensors-detect
# Answer YES to all questions

# Test detection
sensors
```

### No GPU Detected

**NVIDIA:**
```bash
# Install NVIDIA drivers
sudo apt install nvidia-driver-525

# Install nvidia-smi
nvidia-smi
```

**AMD:**
```bash
# Check if amdgpu driver loaded
lsmod | grep amdgpu

# AMD sysfs should be available
ls /sys/class/drm/card*/device/hwmon/*/temp*_input
```

### Fan Control Not Working

```bash
# Check if PWM control available
ls /sys/class/hwmon/hwmon*/pwm*

# Enable fan control (if supported)
sudo pwmconfig

# Set manual mode
echo 1 | sudo tee /sys/class/hwmon/hwmon1/pwm1_enable

# Set fan speed
echo 128 | sudo tee /sys/class/hwmon/hwmon1/pwm1  # 50%
```

### Permission Denied

```bash
# Run with sudo for fan control
sudo python3 src/sensors/fan_controller.py set 0 60

# Or add user to appropriate group
sudo usermod -aG gpio $USER
sudo usermod -aG i2c $USER
```

## 📚 API Reference

See source code for detailed API:
- `src/sensors/gpu_monitor.py` - GPU monitoring
- `src/sensors/universal_sensor_detector.py` - Sensor detection
- `src/sensors/fan_controller.py` - Fan control
- `src/services/monitoring_service.py` - Monitoring service

## 🎯 Next Steps

1. **Install lm-sensors** for full sensor support
2. **Test detection** with provided scripts
3. **Configure fan control** if needed
4. **Run monitoring service** for continuous monitoring

For more information, see [UNIVERSAL_HARDWARE.md](UNIVERSAL_HARDWARE.md)
