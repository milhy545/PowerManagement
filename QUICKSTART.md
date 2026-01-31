# ⚡ Quick Start Guide

**Get started with PowerManagement in 5 minutes!**

## 🚀 Installation

### Option 1: One-Click Install (Recommended)

```bash
# Clone repository
git clone https://github.com/milhy545/PowerManagement.git
cd PowerManagement

# Run installation script
./install.sh
```

That's it! ✅

### Option 2: Manual Install

```bash
# Clone repository
git clone https://github.com/milhy545/PowerManagement.git
cd PowerManagement

# Install dependencies
pip3 install psutil

# Optional: Install lm-sensors for full sensor support
sudo apt install lm-sensors
sudo sensors-detect  # Answer YES to all questions
```

---

## 🎯 First Steps

### 1. Check Your Hardware

```bash
# Detect CPU, GPU, and capabilities
python3 src/hardware/hardware_detector.py
```

**Example Output:**
```
🖥️  CPU: Intel(R) Core(TM)2 Quad CPU Q9550 @ 2.83GHz
   Vendor: INTEL
   Thermal Max: 85°C

🎮 GPU: AMD Radeon RV710
   Power Profile Support: ✅ Yes
```

### 2. View GPU Status

```bash
# Show GPU temperature, fan speed, power
python3 src/sensors/gpu_monitor.py
```

**Example Output:**
```
🎮 GPU: NVIDIA GeForce RTX 3080
  🌡️  Temperature: 62°C
  💨 Fan: 45% (1850 RPM)
  ⚡ Power: 245W / 320W
```

### 3. View All Sensors

```bash
# Detect and show ALL system sensors
python3 src/sensors/universal_sensor_detector.py
```

**Example Output:**
```
🌡️  TEMPERATURE SENSORS (12)
  • Package id 0    : 45.0 °C
  • Core 0          : 42.0 °C
  • GPU edge        : 62.0 °C

💨 FAN SENSORS (6)
  • CPU Fan         : 1245 RPM
  • GPU Fan         : 1850 RPM
```

### 4. Control Fans (Requires sudo)

```bash
# Show controllable fans
python3 src/sensors/fan_controller.py status

# Set CPU fan to 60%
sudo python3 src/sensors/fan_controller.py set 0 60

# Set back to automatic
sudo python3 src/sensors/fan_controller.py auto 0
```

---

## 💪 Power Profiles

### Set Power Mode

```bash
# Maximum performance
./scripts/performance_manager.sh performance

# Balanced (recommended)
./scripts/performance_manager.sh balanced

# Power saving
./scripts/performance_manager.sh powersave

# Emergency (thermal issues)
./scripts/performance_manager.sh emergency
```

### View Current Status

```bash
./scripts/performance_manager.sh status
```

---

## 📊 Real-Time Monitoring

### Start Monitoring Service

```bash
# Start with default settings (5 second interval)
python3 src/services/monitoring_service.py

# Custom interval (10 seconds)
python3 src/services/monitoring_service.py --interval 10

# Disable automatic fan control
python3 src/services/monitoring_service.py --no-auto-fan
```

**What it does:**
- ✅ Monitors CPU & GPU temperature
- ✅ Monitors fan speeds
- ✅ Automatically adjusts fans based on temperature
- ✅ Sends alerts when temps are high
- ✅ Logs data to JSON file

**Example Output:**
```
[22:45:06] 📊 CPU: 45.0°C | GPU: 62.0°C | Fan: 1245RPM
[22:45:11] 📊 CPU: 46.0°C | GPU: 63.0°C | Fan: 1250RPM
[22:45:16] ⚡ CPU WARNING: 72.0°C
[22:45:21] ⚠️  CRITICAL: Setting fans to 75%
```

---

## 🔧 Common Use Cases

### Use Case 1: Gaming / High Performance

```bash
# Set to performance mode
./scripts/performance_manager.sh performance

# Monitor GPU while gaming
watch -n 1 python3 src/sensors/gpu_monitor.py
```

### Use Case 2: Silent Operation

```bash
# Set to power save mode
./scripts/performance_manager.sh powersave

# Manually set fans to 30%
sudo python3 src/sensors/fan_controller.py set 0 30
```

### Use Case 3: Overheating Prevention

```bash
# Start automatic monitoring with fan control
python3 src/services/monitoring_service.py

# It will automatically increase fan speed when temps rise!
```

### Use Case 4: All-in-One PC (Limited Cooling)

```bash
# Start monitoring with aggressive fan control
python3 src/services/monitoring_service.py --interval 3

# The service will keep your AIO PC cool automatically
```

---

## 🆘 Troubleshooting

### No GPU Detected

**NVIDIA:**
```bash
# Check if nvidia-smi works
nvidia-smi

# If not, install NVIDIA drivers
sudo apt install nvidia-driver-525
```

**AMD:**
```bash
# Check if AMD GPU is detected
ls /sys/class/drm/card*/device/vendor

# Should show "0x1002" for AMD
```

### No Sensors Detected

```bash
# Install lm-sensors
sudo apt install lm-sensors

# Detect sensors
sudo sensors-detect
# Answer YES to all questions

# Test
sensors
```

### Fan Control Not Working

```bash
# Check if PWM control exists
ls /sys/class/hwmon/hwmon*/pwm*

# If not, enable in BIOS:
# - Look for "Smart Fan Control" or "PWM Mode"
# - Set to "Manual" or "PWM"
```

### Permission Denied

```bash
# Fan control requires root
sudo python3 src/sensors/fan_controller.py set 0 60

# Or add user to groups
sudo usermod -aG gpio $USER
sudo usermod -aG i2c $USER
# Log out and back in
```

---

## 📖 Learn More

- **[SENSOR_MONITORING.md](docs/SENSOR_MONITORING.md)** - Detailed sensor & fan guide
- **[UNIVERSAL_HARDWARE.md](docs/UNIVERSAL_HARDWARE.md)** - Hardware compatibility
- **[README.md](README.md)** - Full documentation

---

## 🎯 Quick Command Reference

| Task | Command |
|------|---------|
| Show GPU | `python3 src/sensors/gpu_monitor.py` |
| Show Sensors | `python3 src/sensors/universal_sensor_detector.py` |
| Fan Status | `python3 src/sensors/fan_controller.py status` |
| Set Fan Speed | `sudo python3 src/sensors/fan_controller.py set 0 60` |
| Performance Mode | `./scripts/performance_manager.sh performance` |
| Balanced Mode | `./scripts/performance_manager.sh balanced` |
| Power Save Mode | `./scripts/performance_manager.sh powersave` |
| Monitor Service | `python3 src/services/monitoring_service.py` |
| Hardware Info | `python3 src/hardware/hardware_detector.py` |

---

## 💡 Pro Tips

1. **Auto-start monitoring on boot:**
   ```bash
   # Add to crontab
   @reboot cd /path/to/PowerManagement && python3 src/services/monitoring_service.py >> /tmp/power-monitor.log 2>&1
   ```

2. **Monitor GPU while running AI:**
   ```bash
   # In terminal 1: Run AI workload
   # In terminal 2:
   watch -n 1 python3 src/sensors/gpu_monitor.py
   ```

3. **Create desktop shortcuts:**
   ```bash
   # Performance mode shortcut
   echo "./scripts/performance_manager.sh performance" > ~/Desktop/performance.sh
   chmod +x ~/Desktop/performance.sh
   ```

4. **Get alerts on high temps:**
   ```bash
   # The monitoring service automatically alerts
   # Logs are in /tmp/power_monitoring.log
   tail -f /tmp/power_monitoring.log
   ```

---

## 🎉 You're Ready!

Your system is now equipped with professional power management!

**Next Steps:**
- Set your preferred power mode
- Start the monitoring service
- Enjoy optimal performance and cooling!

**Need Help?**
- Check [SENSOR_MONITORING.md](docs/SENSOR_MONITORING.md)
- Open an issue on GitHub
- Read troubleshooting section above
