#!/usr/bin/env python3
"""
Universal GPU Monitor
Monitors GPU temperature, fan speed, power, utilization
Supports: NVIDIA (nvidia-smi), AMD (sysfs), Intel (sysfs)
Works on atypical systems and all-in-one PCs
"""

import os
import re
import subprocess
from pathlib import Path
from typing import Optional, List, Dict
from dataclasses import dataclass
from enum import Enum


class GPUVendor(Enum):
    NVIDIA = "nvidia"
    AMD = "amd"
    INTEL = "intel"
    UNKNOWN = "unknown"


@dataclass
class GPUMetrics:
    """GPU metrics data"""
    vendor: GPUVendor
    name: str
    temperature: Optional[int]  # Celsius
    fan_speed: Optional[int]    # Percentage (0-100)
    fan_rpm: Optional[int]      # RPM
    power_usage: Optional[int]  # Watts
    power_limit: Optional[int]  # Watts
    utilization: Optional[int]  # Percentage
    memory_used: Optional[int]  # MB
    memory_total: Optional[int] # MB
    device_path: Optional[str]  # sysfs path


class UniversalGPUMonitor:
    """
    Universal GPU monitor supporting multiple vendors
    Handles atypical systems, all-in-one PCs, multiple GPUs
    """

    def __init__(self):
        self.gpus = self._detect_all_gpus()
        self.primary_gpu = self.gpus[0] if self.gpus else None

    def _detect_all_gpus(self) -> List[Dict]:
        """Detect all GPUs in the system"""
        gpus = []

        # Try NVIDIA
        nvidia_gpus = self._detect_nvidia_gpus()
        gpus.extend(nvidia_gpus)

        # Try AMD
        amd_gpus = self._detect_amd_gpus()
        gpus.extend(amd_gpus)

        # Try Intel
        intel_gpus = self._detect_intel_gpus()
        gpus.extend(intel_gpus)

        return gpus

    def _detect_nvidia_gpus(self) -> List[Dict]:
        """Detect NVIDIA GPUs using nvidia-smi"""
        gpus = []
        try:
            # Check if nvidia-smi is available
            result = subprocess.run(
                ["nvidia-smi", "--query-gpu=index,name,uuid", "--format=csv,noheader"],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        parts = [p.strip() for p in line.split(',')]
                        if len(parts) >= 2:
                            gpus.append({
                                'vendor': GPUVendor.NVIDIA,
                                'index': int(parts[0]),
                                'name': parts[1],
                                'uuid': parts[2] if len(parts) > 2 else None
                            })
        except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
            pass

        return gpus

    def _detect_amd_gpus(self) -> List[Dict]:
        """Detect AMD GPUs via sysfs"""
        gpus = []
        drm_path = Path("/sys/class/drm")

        if drm_path.exists():
            for card_dir in sorted(drm_path.glob("card[0-9]*")):
                # Skip card*-* (connectors)
                if "-" in card_dir.name:
                    continue

                device_dir = card_dir / "device"
                if not device_dir.exists():
                    continue

                # Check vendor ID
                vendor_file = device_dir / "vendor"
                if vendor_file.exists():
                    vendor_id = vendor_file.read_text().strip()
                    if vendor_id == "0x1002":  # AMD
                        # Get device name
                        name = "AMD GPU"
                        try:
                            # Try to get GPU name from uevent
                            uevent = (device_dir / "uevent").read_text()
                            pci_id_match = re.search(r"PCI_ID=([0-9A-Fa-f:]+)", uevent)
                            if pci_id_match:
                                name = f"AMD GPU {pci_id_match.group(1)}"
                        except Exception:
                            pass

                        gpus.append({
                            'vendor': GPUVendor.AMD,
                            'index': len(gpus),
                            'name': name,
                            'device_path': str(card_dir)
                        })

        return gpus

    def _detect_intel_gpus(self) -> List[Dict]:
        """Detect Intel integrated GPUs via sysfs"""
        gpus = []
        drm_path = Path("/sys/class/drm")

        if drm_path.exists():
            for card_dir in sorted(drm_path.glob("card[0-9]*")):
                if "-" in card_dir.name:
                    continue

                device_dir = card_dir / "device"
                if not device_dir.exists():
                    continue

                vendor_file = device_dir / "vendor"
                if vendor_file.exists():
                    vendor_id = vendor_file.read_text().strip()
                    if vendor_id == "0x8086":  # Intel
                        name = "Intel Integrated Graphics"

                        gpus.append({
                            'vendor': GPUVendor.INTEL,
                            'index': len(gpus),
                            'name': name,
                            'device_path': str(card_dir)
                        })

        return gpus

    def get_nvidia_metrics(self, gpu_index: int = 0) -> Optional[GPUMetrics]:
        """Get metrics for NVIDIA GPU"""
        try:
            # Query multiple metrics at once
            query = "temperature.gpu,fan.speed,power.draw,power.limit,utilization.gpu,memory.used,memory.total"
            result = subprocess.run(
                ["nvidia-smi", f"--id={gpu_index}",
                 f"--query-gpu={query}",
                 "--format=csv,noheader,nounits"],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode != 0:
                return None

            # Parse output
            values = [v.strip() for v in result.stdout.strip().split(',')]

            # Get GPU name
            name_result = subprocess.run(
                ["nvidia-smi", f"--id={gpu_index}", "--query-gpu=name", "--format=csv,noheader"],
                capture_output=True,
                text=True,
                timeout=3
            )
            name = name_result.stdout.strip() if name_result.returncode == 0 else "NVIDIA GPU"

            return GPUMetrics(
                vendor=GPUVendor.NVIDIA,
                name=name,
                temperature=int(float(values[0])) if values[0] != 'N/A' else None,
                fan_speed=int(float(values[1])) if values[1] != 'N/A' else None,
                fan_rpm=None,  # nvidia-smi doesn't provide RPM directly
                power_usage=int(float(values[2])) if values[2] != 'N/A' else None,
                power_limit=int(float(values[3])) if values[3] != 'N/A' else None,
                utilization=int(float(values[4])) if values[4] != 'N/A' else None,
                memory_used=int(float(values[5])) if values[5] != 'N/A' else None,
                memory_total=int(float(values[6])) if values[6] != 'N/A' else None,
                device_path=None
            )

        except Exception as e:
            print(f"NVIDIA metrics error: {e}")
            return None

    def get_amd_metrics(self, device_path: str) -> Optional[GPUMetrics]:
        """Get metrics for AMD GPU via sysfs"""
        try:
            card_path = Path(device_path)
            device_dir = card_path / "device"
            hwmon_dir = device_dir / "hwmon"

            name = "AMD GPU"
            temperature = None
            fan_speed = None
            fan_rpm = None
            power_usage = None

            # Find hwmon directory
            hwmon_path = None
            if hwmon_dir.exists():
                hwmon_subdirs = list(hwmon_dir.glob("hwmon*"))
                if hwmon_subdirs:
                    hwmon_path = hwmon_subdirs[0]

            if hwmon_path:
                # Temperature (look for edge temperature)
                temp_inputs = list(hwmon_path.glob("temp*_input"))
                for temp_file in temp_inputs:
                    label_file = temp_file.parent / temp_file.name.replace("_input", "_label")
                    if label_file.exists():
                        label = label_file.read_text().strip()
                        if "edge" in label.lower() or "junction" in label.lower():
                            temp_milli = int(temp_file.read_text().strip())
                            temperature = temp_milli // 1000
                            break

                # If no labeled temp found, use first temp sensor
                if temperature is None and temp_inputs:
                    temp_milli = int(temp_inputs[0].read_text().strip())
                    temperature = temp_milli // 1000

                # Fan speed (PWM = 0-255, convert to percentage)
                pwm_files = list(hwmon_path.glob("pwm[0-9]"))
                if pwm_files:
                    pwm_value = int(pwm_files[0].read_text().strip())
                    fan_speed = int((pwm_value / 255) * 100)

                # Fan RPM
                fan_input_files = list(hwmon_path.glob("fan*_input"))
                if fan_input_files:
                    fan_rpm = int(fan_input_files[0].read_text().strip())

                # Power usage
                power_files = list(hwmon_path.glob("power*_average"))
                if power_files:
                    power_micro = int(power_files[0].read_text().strip())
                    power_usage = power_micro // 1000000  # Convert to watts

            return GPUMetrics(
                vendor=GPUVendor.AMD,
                name=name,
                temperature=temperature,
                fan_speed=fan_speed,
                fan_rpm=fan_rpm,
                power_usage=power_usage,
                power_limit=None,
                utilization=None,  # AMD doesn't expose this easily
                memory_used=None,
                memory_total=None,
                device_path=device_path
            )

        except Exception as e:
            print(f"AMD metrics error: {e}")
            return None

    def get_intel_metrics(self, device_path: str) -> Optional[GPUMetrics]:
        """Get metrics for Intel iGPU via sysfs"""
        try:
            card_path = Path(device_path)
            device_dir = card_path / "device"
            hwmon_dir = device_dir / "hwmon"

            name = "Intel Integrated Graphics"
            temperature = None
            power_usage = None

            # Find hwmon directory
            hwmon_path = None
            if hwmon_dir.exists():
                hwmon_subdirs = list(hwmon_dir.glob("hwmon*"))
                if hwmon_subdirs:
                    hwmon_path = hwmon_subdirs[0]

            if hwmon_path:
                # Temperature
                temp_inputs = list(hwmon_path.glob("temp*_input"))
                if temp_inputs:
                    temp_milli = int(temp_inputs[0].read_text().strip())
                    temperature = temp_milli // 1000

                # Power
                power_files = list(hwmon_path.glob("power*_average"))
                if power_files:
                    power_micro = int(power_files[0].read_text().strip())
                    power_usage = power_micro // 1000000

            return GPUMetrics(
                vendor=GPUVendor.INTEL,
                name=name,
                temperature=temperature,
                fan_speed=None,  # Intel iGPU typically shares CPU fan
                fan_rpm=None,
                power_usage=power_usage,
                power_limit=None,
                utilization=None,
                memory_used=None,
                memory_total=None,
                device_path=device_path
            )

        except Exception as e:
            print(f"Intel metrics error: {e}")
            return None

    def get_metrics(self, gpu_index: int = 0) -> Optional[GPUMetrics]:
        """Get metrics for specified GPU"""
        if gpu_index >= len(self.gpus):
            return None

        gpu = self.gpus[gpu_index]
        vendor = gpu['vendor']

        if vendor == GPUVendor.NVIDIA:
            return self.get_nvidia_metrics(gpu.get('index', 0))
        elif vendor == GPUVendor.AMD:
            return self.get_amd_metrics(gpu['device_path'])
        elif vendor == GPUVendor.INTEL:
            return self.get_intel_metrics(gpu['device_path'])

        return None

    def get_all_metrics(self) -> List[GPUMetrics]:
        """Get metrics for all GPUs"""
        metrics = []
        for i in range(len(self.gpus)):
            m = self.get_metrics(i)
            if m:
                metrics.append(m)
        return metrics

    def print_metrics(self, metrics: GPUMetrics):
        """Print GPU metrics in human-readable format"""
        print(f"🎮 {metrics.name} ({metrics.vendor.value.upper()})")
        print(f"   🌡️  Temperature: {metrics.temperature}°C" if metrics.temperature else "   🌡️  Temperature: N/A")

        if metrics.fan_speed is not None:
            print(f"   💨 Fan Speed: {metrics.fan_speed}%", end="")
            if metrics.fan_rpm:
                print(f" ({metrics.fan_rpm} RPM)")
            else:
                print()

        if metrics.power_usage is not None:
            power_str = f"   ⚡ Power: {metrics.power_usage}W"
            if metrics.power_limit:
                power_str += f" / {metrics.power_limit}W"
            print(power_str)

        if metrics.utilization is not None:
            print(f"   📊 Utilization: {metrics.utilization}%")

        if metrics.memory_used is not None and metrics.memory_total is not None:
            print(f"   💾 Memory: {metrics.memory_used}MB / {metrics.memory_total}MB")

    def generate_report(self) -> str:
        """Generate comprehensive GPU report"""
        lines = []
        lines.append("=" * 60)
        lines.append("🎮 GPU MONITORING REPORT")
        lines.append("=" * 60)
        lines.append("")

        if not self.gpus:
            lines.append("❌ No GPUs detected")
            lines.append("")
            lines.append("=" * 60)
            return "\n".join(lines)

        lines.append(f"📊 Detected GPUs: {len(self.gpus)}")
        lines.append("")

        for i, gpu in enumerate(self.gpus):
            lines.append(f"GPU #{i}: {gpu['name']} ({gpu['vendor'].value.upper()})")

            metrics = self.get_metrics(i)
            if metrics:
                if metrics.temperature is not None:
                    lines.append(f"  🌡️  Temperature: {metrics.temperature}°C")
                if metrics.fan_speed is not None:
                    fan_line = f"  💨 Fan: {metrics.fan_speed}%"
                    if metrics.fan_rpm:
                        fan_line += f" ({metrics.fan_rpm} RPM)"
                    lines.append(fan_line)
                if metrics.power_usage is not None:
                    power_line = f"  ⚡ Power: {metrics.power_usage}W"
                    if metrics.power_limit:
                        power_line += f" / {metrics.power_limit}W"
                    lines.append(power_line)
                if metrics.utilization is not None:
                    lines.append(f"  📊 Utilization: {metrics.utilization}%")
                if metrics.memory_used is not None and metrics.memory_total is not None:
                    mem_pct = int((metrics.memory_used / metrics.memory_total) * 100)
                    lines.append(f"  💾 Memory: {metrics.memory_used}MB / {metrics.memory_total}MB ({mem_pct}%)")
            else:
                lines.append("  ⚠️  Unable to read metrics")

            lines.append("")

        lines.append("=" * 60)
        return "\n".join(lines)


def main():
    """Test GPU monitoring"""
    monitor = UniversalGPUMonitor()
    print(monitor.generate_report())


if __name__ == "__main__":
    main()
