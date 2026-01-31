#!/usr/bin/env python3
"""
Universal Sensor Detector
Detects ALL possible sensors in the system
Works on atypical motherboards, all-in-one PCs, exotic configurations
Finds: CPU temps, GPU temps, motherboard sensors, fan sensors, voltage, power
"""

import os
import re
import subprocess
from pathlib import Path
from typing import List, Dict, Optional
from dataclasses import dataclass
from enum import Enum


class SensorType(Enum):
    TEMPERATURE = "temperature"
    FAN = "fan"
    VOLTAGE = "voltage"
    POWER = "power"
    CURRENT = "current"
    ENERGY = "energy"
    HUMIDITY = "humidity"
    UNKNOWN = "unknown"


@dataclass
class Sensor:
    """Individual sensor data"""
    name: str
    type: SensorType
    value: Optional[float]
    unit: str
    path: Optional[str]
    chip: str
    label: str


class UniversalSensorDetector:
    """
    Universal sensor detector
    Finds sensors from:
    - lm-sensors (sensors command)
    - sysfs (/sys/class/hwmon, /sys/class/thermal)
    - ACPI (/sys/class/power_supply)
    - GPU-specific (nvidia-smi, AMD/Intel sysfs)
    """

    def __init__(self):
        self.sensors = []
        self._detect_all_sensors()

    def _detect_all_sensors(self):
        """Detect all available sensors"""
        # Method 1: lm-sensors (most comprehensive)
        self._detect_lm_sensors()

        # Method 2: sysfs hwmon
        self._detect_sysfs_hwmon()

        # Method 3: thermal zones
        self._detect_thermal_zones()

        # Method 4: ACPI power
        self._detect_acpi_sensors()

        # Remove duplicates
        self._deduplicate_sensors()

    def _detect_lm_sensors(self):
        """Detect sensors using lm-sensors (sensors command)"""
        try:
            result = subprocess.run(
                ["sensors", "-A"],  # -A shows all sensors
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode != 0:
                return

            current_chip = "unknown"
            for line in result.stdout.split('\n'):
                line = line.strip()
                if not line:
                    continue

                # Chip name (e.g., "coretemp-isa-0000")
                if not line.startswith(' ') and ':' not in line:
                    current_chip = line
                    continue

                # Sensor reading (e.g., "Core 0:        +45.0°C")
                if ':' in line:
                    parts = line.split(':', 1)
                    label = parts[0].strip()
                    value_str = parts[1].strip()

                    # Parse value
                    sensor = self._parse_sensor_line(label, value_str, current_chip)
                    if sensor:
                        self.sensors.append(sensor)

        except (FileNotFoundError, subprocess.TimeoutExpired, Exception) as e:
            # lm-sensors not available, continue with other methods
            pass

    def _parse_sensor_line(self, label: str, value_str: str, chip: str) -> Optional[Sensor]:
        """Parse a sensor line from lm-sensors output"""
        # Temperature
        if '°C' in value_str or 'C' in value_str:
            match = re.search(r'([+-]?\d+\.?\d*)\s*°?C', value_str)
            if match:
                return Sensor(
                    name=f"{chip}/{label}",
                    type=SensorType.TEMPERATURE,
                    value=float(match.group(1)),
                    unit="°C",
                    path=None,
                    chip=chip,
                    label=label
                )

        # Fan (RPM)
        if 'RPM' in value_str or 'rpm' in value_str:
            match = re.search(r'(\d+)\s*RPM', value_str, re.IGNORECASE)
            if match:
                return Sensor(
                    name=f"{chip}/{label}",
                    type=SensorType.FAN,
                    value=float(match.group(1)),
                    unit="RPM",
                    path=None,
                    chip=chip,
                    label=label
                )

        # Voltage
        if 'V' in value_str and '°' not in value_str:
            match = re.search(r'([+-]?\d+\.?\d*)\s*V', value_str)
            if match:
                return Sensor(
                    name=f"{chip}/{label}",
                    type=SensorType.VOLTAGE,
                    value=float(match.group(1)),
                    unit="V",
                    path=None,
                    chip=chip,
                    label=label
                )

        # Power
        if 'W' in value_str:
            match = re.search(r'(\d+\.?\d*)\s*W', value_str)
            if match:
                return Sensor(
                    name=f"{chip}/{label}",
                    type=SensorType.POWER,
                    value=float(match.group(1)),
                    unit="W",
                    path=None,
                    chip=chip,
                    label=label
                )

        return None

    def _detect_sysfs_hwmon(self):
        """Detect sensors via sysfs hwmon"""
        hwmon_base = Path("/sys/class/hwmon")
        if not hwmon_base.exists():
            return

        for hwmon_dir in hwmon_base.glob("hwmon*"):
            chip_name = "unknown"

            # Get chip name
            name_file = hwmon_dir / "name"
            if name_file.exists():
                chip_name = name_file.read_text().strip()

            # Temperature sensors
            for temp_file in hwmon_dir.glob("temp*_input"):
                try:
                    label = temp_file.stem.replace("_input", "")
                    label_file = hwmon_dir / f"{temp_file.stem.replace('_input', '_label')}"

                    if label_file.exists():
                        label = label_file.read_text().strip()

                    temp_milli = int(temp_file.read_text().strip())
                    temp_celsius = temp_milli / 1000.0

                    self.sensors.append(Sensor(
                        name=f"{chip_name}/{label}",
                        type=SensorType.TEMPERATURE,
                        value=temp_celsius,
                        unit="°C",
                        path=str(temp_file),
                        chip=chip_name,
                        label=label
                    ))
                except Exception:
                    pass

            # Fan sensors
            for fan_file in hwmon_dir.glob("fan*_input"):
                try:
                    label = fan_file.stem.replace("_input", "")
                    label_file = hwmon_dir / f"{fan_file.stem.replace('_input', '_label')}"

                    if label_file.exists():
                        label = label_file.read_text().strip()

                    rpm = int(fan_file.read_text().strip())

                    self.sensors.append(Sensor(
                        name=f"{chip_name}/{label}",
                        type=SensorType.FAN,
                        value=float(rpm),
                        unit="RPM",
                        path=str(fan_file),
                        chip=chip_name,
                        label=label
                    ))
                except Exception:
                    pass

            # Voltage sensors
            for in_file in hwmon_dir.glob("in*_input"):
                try:
                    label = in_file.stem.replace("_input", "")
                    label_file = hwmon_dir / f"{in_file.stem.replace('_input', '_label')}"

                    if label_file.exists():
                        label = label_file.read_text().strip()

                    voltage_mv = int(in_file.read_text().strip())
                    voltage = voltage_mv / 1000.0

                    self.sensors.append(Sensor(
                        name=f"{chip_name}/{label}",
                        type=SensorType.VOLTAGE,
                        value=voltage,
                        unit="V",
                        path=str(in_file),
                        chip=chip_name,
                        label=label
                    ))
                except Exception:
                    pass

            # Power sensors
            for power_file in hwmon_dir.glob("power*_average"):
                try:
                    label = power_file.stem.replace("_average", "")
                    label_file = hwmon_dir / f"{label}_label"

                    if label_file.exists():
                        label = label_file.read_text().strip()

                    power_micro = int(power_file.read_text().strip())
                    power = power_micro / 1000000.0

                    self.sensors.append(Sensor(
                        name=f"{chip_name}/{label}",
                        type=SensorType.POWER,
                        value=power,
                        unit="W",
                        path=str(power_file),
                        chip=chip_name,
                        label=label
                    ))
                except Exception:
                    pass

    def _detect_thermal_zones(self):
        """Detect thermal zones"""
        thermal_base = Path("/sys/class/thermal")
        if not thermal_base.exists():
            return

        for zone_dir in thermal_base.glob("thermal_zone*"):
            try:
                zone_name = zone_dir.name

                # Get zone type (label)
                type_file = zone_dir / "type"
                label = type_file.read_text().strip() if type_file.exists() else zone_name

                # Get temperature
                temp_file = zone_dir / "temp"
                if temp_file.exists():
                    temp_milli = int(temp_file.read_text().strip())
                    temp_celsius = temp_milli / 1000.0

                    self.sensors.append(Sensor(
                        name=f"thermal/{label}",
                        type=SensorType.TEMPERATURE,
                        value=temp_celsius,
                        unit="°C",
                        path=str(temp_file),
                        chip="thermal_zone",
                        label=label
                    ))
            except Exception:
                pass

    def _detect_acpi_sensors(self):
        """Detect ACPI sensors (battery, AC adapter)"""
        power_base = Path("/sys/class/power_supply")
        if not power_base.exists():
            return

        for supply_dir in power_base.iterdir():
            try:
                supply_name = supply_dir.name

                # Battery voltage
                voltage_file = supply_dir / "voltage_now"
                if voltage_file.exists():
                    voltage_micro = int(voltage_file.read_text().strip())
                    voltage = voltage_micro / 1000000.0

                    self.sensors.append(Sensor(
                        name=f"power/{supply_name}/voltage",
                        type=SensorType.VOLTAGE,
                        value=voltage,
                        unit="V",
                        path=str(voltage_file),
                        chip="acpi",
                        label=f"{supply_name} voltage"
                    ))

                # Battery current
                current_file = supply_dir / "current_now"
                if current_file.exists():
                    current_micro = int(current_file.read_text().strip())
                    current = current_micro / 1000000.0

                    self.sensors.append(Sensor(
                        name=f"power/{supply_name}/current",
                        type=SensorType.CURRENT,
                        value=current,
                        unit="A",
                        path=str(current_file),
                        chip="acpi",
                        label=f"{supply_name} current"
                    ))

                # Battery power
                power_file = supply_dir / "power_now"
                if power_file.exists():
                    power_micro = int(power_file.read_text().strip())
                    power = power_micro / 1000000.0

                    self.sensors.append(Sensor(
                        name=f"power/{supply_name}/power",
                        type=SensorType.POWER,
                        value=power,
                        unit="W",
                        path=str(power_file),
                        chip="acpi",
                        label=f"{supply_name} power"
                    ))

                # Battery energy
                energy_file = supply_dir / "energy_now"
                if energy_file.exists():
                    energy_micro = int(energy_file.read_text().strip())
                    energy = energy_micro / 1000000.0

                    self.sensors.append(Sensor(
                        name=f"power/{supply_name}/energy",
                        type=SensorType.ENERGY,
                        value=energy,
                        unit="Wh",
                        path=str(energy_file),
                        chip="acpi",
                        label=f"{supply_name} energy"
                    ))

            except Exception:
                pass

    def _deduplicate_sensors(self):
        """Remove duplicate sensors"""
        seen = set()
        unique_sensors = []

        for sensor in self.sensors:
            # Create unique key
            key = (sensor.chip, sensor.label, sensor.type)
            if key not in seen:
                seen.add(key)
                unique_sensors.append(sensor)

        self.sensors = unique_sensors

    def get_sensors_by_type(self, sensor_type: SensorType) -> List[Sensor]:
        """Get all sensors of a specific type"""
        return [s for s in self.sensors if s.type == sensor_type]

    def get_temperature_sensors(self) -> List[Sensor]:
        """Get all temperature sensors"""
        return self.get_sensors_by_type(SensorType.TEMPERATURE)

    def get_fan_sensors(self) -> List[Sensor]:
        """Get all fan sensors"""
        return self.get_sensors_by_type(SensorType.FAN)

    def generate_report(self) -> str:
        """Generate comprehensive sensor report"""
        lines = []
        lines.append("=" * 70)
        lines.append("🔍 UNIVERSAL SENSOR DETECTION REPORT")
        lines.append("=" * 70)
        lines.append("")
        lines.append(f"📊 Total Sensors Detected: {len(self.sensors)}")
        lines.append("")

        # Group by type
        for sensor_type in SensorType:
            sensors = self.get_sensors_by_type(sensor_type)
            if not sensors:
                continue

            icon = {
                SensorType.TEMPERATURE: "🌡️",
                SensorType.FAN: "💨",
                SensorType.VOLTAGE: "⚡",
                SensorType.POWER: "🔌",
                SensorType.CURRENT: "⚡",
                SensorType.ENERGY: "🔋",
            }.get(sensor_type, "📊")

            lines.append(f"{icon}  {sensor_type.value.upper()} SENSORS ({len(sensors)})")
            lines.append("-" * 70)

            for sensor in sensors:
                value_str = f"{sensor.value:.1f} {sensor.unit}" if sensor.value is not None else "N/A"
                lines.append(f"  • {sensor.label:30} : {value_str:15} [{sensor.chip}]")

            lines.append("")

        lines.append("=" * 70)
        return "\n".join(lines)

    def get_summary(self) -> Dict:
        """Get summary statistics"""
        return {
            'total_sensors': len(self.sensors),
            'temperature_sensors': len(self.get_temperature_sensors()),
            'fan_sensors': len(self.get_fan_sensors()),
            'voltage_sensors': len(self.get_sensors_by_type(SensorType.VOLTAGE)),
            'power_sensors': len(self.get_sensors_by_type(SensorType.POWER)),
        }


def main():
    """Test universal sensor detection"""
    print("🔍 Detecting all system sensors...")
    print()

    detector = UniversalSensorDetector()
    print(detector.generate_report())

    print("\n📊 Summary:")
    summary = detector.get_summary()
    for key, value in summary.items():
        print(f"  {key}: {value}")


if __name__ == "__main__":
    main()
