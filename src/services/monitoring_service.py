#!/usr/bin/env python3
"""
Power Management Monitoring Service
Real-time monitoring of all system sensors, GPU, fans
Professional monitoring daemon with alerts and auto-adjustment
"""

import os
import sys
import time
import signal
import json
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
from threading import Thread, Event

# Add parent directories to path
service_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(service_dir.parent))

from sensors.gpu_monitor import UniversalGPUMonitor
from sensors.universal_sensor_detector import UniversalSensorDetector, SensorType
from sensors.fan_controller import UniversalFanController
from hardware.hardware_detector import HardwareDetector
from config.power_config import PowerConfig


@dataclass
class MonitoringSnapshot:
    """Single monitoring snapshot"""
    timestamp: str
    cpu_temp: Optional[float]
    gpu_temp: Optional[float]
    cpu_fan_rpm: Optional[int]
    gpu_fan_rpm: Optional[int]
    gpu_power: Optional[int]
    cpu_power: Optional[float]
    voltages: Dict[str, float]
    alerts: List[str]


class MonitoringService:
    """
    Comprehensive monitoring service
    Monitors: CPU, GPU, fans, voltages, power
    Features: Auto fan control, thermal alerts, data logging
    """

    def __init__(self, interval: int = 5, log_dir: str = "/tmp"):
        self.interval = interval
        self.log_dir = Path(log_dir)
        self.log_file = self.log_dir / "power_monitoring.log"
        self.json_log = self.log_dir / "power_monitoring.json"

        # Initialize detectors
        self.hw_detector = HardwareDetector()
        self.sensor_detector = UniversalSensorDetector()
        self.gpu_monitor = UniversalGPUMonitor()
        self.fan_controller = UniversalFanController()

        # Configuration
        self.config = PowerConfig()
        self.config.set_thermal_config(self.hw_detector.cpu_info.thermal_max_safe)

        # Thermal thresholds
        self.cpu_temp_warning = self.config.thermal.warning_temp
        self.cpu_temp_critical = self.config.thermal.critical_temp
        self.cpu_temp_emergency = self.config.thermal.emergency_temp

        # GPU thresholds (typically higher than CPU)
        self.gpu_temp_warning = 75
        self.gpu_temp_critical = 85
        self.gpu_temp_emergency = 95

        # State
        self.running = False
        self.stop_event = Event()
        self.snapshots = []
        self.max_snapshots = 100  # Keep last 100 snapshots in memory

        # Auto fan control
        self.auto_fan_control = True
        self.fan_speed_map = {
            'low': 30,      # < warning temp
            'medium': 50,   # warning to critical
            'high': 75,     # critical to emergency
            'max': 100      # emergency
        }

    def log(self, message: str):
        """Log message to file and stdout"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] {message}"
        print(log_msg)

        try:
            with open(self.log_file, 'a') as f:
                f.write(log_msg + "\n")
        except Exception:
            pass

    def collect_snapshot(self) -> MonitoringSnapshot:
        """Collect single monitoring snapshot"""
        alerts = []

        # Get CPU temperature
        cpu_temp = None
        temp_sensors = self.sensor_detector.get_temperature_sensors()
        if temp_sensors:
            # Find CPU temp (usually coretemp or k10temp)
            for sensor in temp_sensors:
                if any(x in sensor.chip.lower() for x in ['coretemp', 'k10temp', 'cpu']):
                    if 'package' in sensor.label.lower() or 'tctl' in sensor.label.lower():
                        cpu_temp = sensor.value
                        break

            # Fallback to first temp sensor
            if cpu_temp is None and temp_sensors:
                cpu_temp = temp_sensors[0].value

        # Check CPU temp alerts
        if cpu_temp:
            if cpu_temp >= self.cpu_temp_emergency:
                alerts.append(f"🚨 CPU EMERGENCY: {cpu_temp}°C (limit: {self.cpu_temp_emergency}°C)")
            elif cpu_temp >= self.cpu_temp_critical:
                alerts.append(f"⚠️  CPU CRITICAL: {cpu_temp}°C")
            elif cpu_temp >= self.cpu_temp_warning:
                alerts.append(f"⚡ CPU WARNING: {cpu_temp}°C")

        # Get GPU metrics
        gpu_temp = None
        gpu_power = None
        gpu_fan_rpm = None

        gpu_metrics_list = self.gpu_monitor.get_all_metrics()
        if gpu_metrics_list:
            gpu_metrics = gpu_metrics_list[0]  # Primary GPU
            gpu_temp = gpu_metrics.temperature
            gpu_power = gpu_metrics.power_usage
            gpu_fan_rpm = gpu_metrics.fan_rpm

            # Check GPU temp alerts
            if gpu_temp:
                if gpu_temp >= self.gpu_temp_emergency:
                    alerts.append(f"🚨 GPU EMERGENCY: {gpu_temp}°C (limit: {self.gpu_temp_emergency}°C)")
                elif gpu_temp >= self.gpu_temp_critical:
                    alerts.append(f"⚠️  GPU CRITICAL: {gpu_temp}°C")
                elif gpu_temp >= self.gpu_temp_warning:
                    alerts.append(f"⚡ GPU WARNING: {gpu_temp}°C")

        # Get fan speeds
        cpu_fan_rpm = None
        fan_sensors = self.sensor_detector.get_fan_sensors()
        if fan_sensors:
            # Find CPU fan
            for sensor in fan_sensors:
                if 'cpu' in sensor.label.lower() or 'fan1' in sensor.label.lower():
                    cpu_fan_rpm = int(sensor.value) if sensor.value else None
                    break

            # Fallback to first fan
            if cpu_fan_rpm is None and fan_sensors:
                cpu_fan_rpm = int(fan_sensors[0].value) if fan_sensors[0].value else None

        # Get voltages
        voltages = {}
        voltage_sensors = self.sensor_detector.get_sensors_by_type(SensorType.VOLTAGE)
        for sensor in voltage_sensors[:5]:  # Limit to first 5
            voltages[sensor.label] = sensor.value

        # Get CPU power if available
        cpu_power = None
        power_sensors = self.sensor_detector.get_sensors_by_type(SensorType.POWER)
        for sensor in power_sensors:
            if 'package' in sensor.label.lower() or 'cpu' in sensor.label.lower():
                cpu_power = sensor.value
                break

        return MonitoringSnapshot(
            timestamp=datetime.now().isoformat(),
            cpu_temp=cpu_temp,
            gpu_temp=gpu_temp,
            cpu_fan_rpm=cpu_fan_rpm,
            gpu_fan_rpm=gpu_fan_rpm,
            gpu_power=gpu_power,
            cpu_power=cpu_power,
            voltages=voltages,
            alerts=alerts
        )

    def adjust_fans_based_on_temp(self, snapshot: MonitoringSnapshot):
        """Auto-adjust fans based on temperatures"""
        if not self.auto_fan_control:
            return

        # Determine required fan speed based on max temp
        max_temp = 0
        if snapshot.cpu_temp:
            max_temp = max(max_temp, snapshot.cpu_temp)
        if snapshot.gpu_temp:
            max_temp = max(max_temp, snapshot.gpu_temp)

        if max_temp == 0:
            return  # No temp data

        # Determine fan speed tier
        if max_temp >= self.cpu_temp_emergency or (snapshot.gpu_temp and snapshot.gpu_temp >= self.gpu_temp_emergency):
            target_speed = self.fan_speed_map['max']
            self.log(f"🚨 EMERGENCY: Setting fans to {target_speed}%")
        elif max_temp >= self.cpu_temp_critical or (snapshot.gpu_temp and snapshot.gpu_temp >= self.gpu_temp_critical):
            target_speed = self.fan_speed_map['high']
            self.log(f"⚠️  CRITICAL: Setting fans to {target_speed}%")
        elif max_temp >= self.cpu_temp_warning or (snapshot.gpu_temp and snapshot.gpu_temp >= self.gpu_temp_warning):
            target_speed = self.fan_speed_map['medium']
        else:
            target_speed = self.fan_speed_map['low']

        # Set all controllable fans
        for i in range(len(self.fan_controller.pwm_fans)):
            try:
                self.fan_controller.set_pwm_fan_speed(i, target_speed)
            except Exception as e:
                self.log(f"Fan control error: {e}")

    def save_snapshot_to_json(self, snapshot: MonitoringSnapshot):
        """Save snapshot to JSON log"""
        try:
            # Load existing data
            data = []
            if self.json_log.exists():
                with open(self.json_log, 'r') as f:
                    data = json.load(f)

            # Append new snapshot
            data.append(asdict(snapshot))

            # Keep only last 1000 snapshots
            if len(data) > 1000:
                data = data[-1000:]

            # Save
            with open(self.json_log, 'w') as f:
                json.dump(data, f, indent=2)

        except Exception as e:
            self.log(f"JSON log error: {e}")

    def monitoring_loop(self):
        """Main monitoring loop"""
        self.log("🚀 Monitoring service started")
        self.log(f"   CPU: {self.hw_detector.cpu_info.model_name}")
        self.log(f"   Thermal limits: {self.cpu_temp_warning}°C / {self.cpu_temp_critical}°C / {self.cpu_temp_emergency}°C")
        self.log(f"   Interval: {self.interval}s")
        self.log(f"   Auto fan control: {'✅ Enabled' if self.auto_fan_control else '❌ Disabled'}")

        while not self.stop_event.is_set():
            try:
                # Collect snapshot
                snapshot = self.collect_snapshot()

                # Store in memory
                self.snapshots.append(snapshot)
                if len(self.snapshots) > self.max_snapshots:
                    self.snapshots.pop(0)

                # Log to JSON
                self.save_snapshot_to_json(snapshot)

                # Display current status
                status_parts = []
                if snapshot.cpu_temp:
                    status_parts.append(f"CPU: {snapshot.cpu_temp:.1f}°C")
                if snapshot.gpu_temp:
                    status_parts.append(f"GPU: {snapshot.gpu_temp:.1f}°C")
                if snapshot.cpu_fan_rpm:
                    status_parts.append(f"Fan: {snapshot.cpu_fan_rpm}RPM")

                status = " | ".join(status_parts)
                self.log(f"📊 {status}")

                # Log alerts
                for alert in snapshot.alerts:
                    self.log(alert)

                # Auto-adjust fans
                self.adjust_fans_based_on_temp(snapshot)

                # Sleep
                self.stop_event.wait(self.interval)

            except Exception as e:
                self.log(f"❌ Monitoring error: {e}")
                self.stop_event.wait(self.interval)

    def start(self):
        """Start monitoring service"""
        if self.running:
            print("Service already running")
            return

        self.running = True
        self.stop_event.clear()

        # Start monitoring thread
        self.monitor_thread = Thread(target=self.monitoring_loop, daemon=True)
        self.monitor_thread.start()

    def stop(self):
        """Stop monitoring service"""
        if not self.running:
            return

        self.log("🛑 Stopping monitoring service...")
        self.stop_event.set()
        self.monitor_thread.join(timeout=5)
        self.running = False

    def get_current_status(self) -> Optional[MonitoringSnapshot]:
        """Get most recent snapshot"""
        return self.snapshots[-1] if self.snapshots else None


def signal_handler(signum, frame):
    """Handle shutdown signals"""
    print("\n🛑 Received shutdown signal")
    sys.exit(0)


def main():
    """Run monitoring service"""
    import argparse

    parser = argparse.ArgumentParser(description="Power Management Monitoring Service")
    parser.add_argument("--interval", type=int, default=5, help="Monitoring interval in seconds")
    parser.add_argument("--no-auto-fan", action="store_true", help="Disable automatic fan control")
    parser.add_argument("--log-dir", type=str, default="/tmp", help="Log directory")
    args = parser.parse_args()

    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # Create service
    service = MonitoringService(
        interval=args.interval,
        log_dir=args.log_dir
    )

    if args.no_auto_fan:
        service.auto_fan_control = False

    # Start service
    service.start()

    # Keep running
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        service.stop()


if __name__ == "__main__":
    main()
