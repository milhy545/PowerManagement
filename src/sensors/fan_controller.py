#!/usr/bin/env python3
"""
Universal Fan Controller
Controls CPU and GPU fans on all platforms
Supports: PWM control (Linux), NVIDIA GPUs, AMD GPUs
Works on atypical systems including all-in-one PCs
"""

import os
import subprocess
from pathlib import Path
from typing import List, Optional, Dict
from dataclasses import dataclass
from enum import Enum


class FanControlMode(Enum):
    AUTO = "auto"
    MANUAL = "manual"


@dataclass
class FanInfo:
    """Fan information"""
    name: str
    current_speed: Optional[int]  # RPM
    current_pwm: Optional[int]    # 0-255
    current_percent: Optional[int]  # 0-100
    pwm_path: Optional[str]
    pwm_enable_path: Optional[str]
    mode: FanControlMode


class UniversalFanController:
    """
    Universal fan controller
    Controls:
    - CPU fans via PWM (sysfs)
    - Case fans via PWM
    - GPU fans (NVIDIA via nvidia-settings, AMD via sysfs)
    """

    def __init__(self):
        self.pwm_fans = self._detect_pwm_fans()
        self.gpu_fans = self._detect_gpu_fans()

    def _detect_pwm_fans(self) -> List[Dict]:
        """Detect all PWM-controllable fans"""
        fans = []
        hwmon_base = Path("/sys/class/hwmon")

        if not hwmon_base.exists():
            return fans

        for hwmon_dir in hwmon_base.glob("hwmon*"):
            chip_name = "unknown"

            # Get chip name
            name_file = hwmon_dir / "name"
            if name_file.exists():
                chip_name = name_file.read_text().strip()

            # Find PWM controls
            for pwm_file in hwmon_dir.glob("pwm[0-9]"):
                try:
                    pwm_num = pwm_file.name.replace("pwm", "")

                    # Get PWM enable path (for switching modes)
                    pwm_enable_file = hwmon_dir / f"pwm{pwm_num}_enable"

                    # Get fan input (RPM) if available
                    fan_input_file = hwmon_dir / f"fan{pwm_num}_input"

                    # Get current PWM value
                    current_pwm = int(pwm_file.read_text().strip())

                    # Get current RPM if available
                    current_rpm = None
                    if fan_input_file.exists():
                        try:
                            current_rpm = int(fan_input_file.read_text().strip())
                        except Exception:
                            pass

                    # Get current mode
                    mode = FanControlMode.AUTO
                    if pwm_enable_file.exists():
                        try:
                            enable_value = int(pwm_enable_file.read_text().strip())
                            # 0 = full speed, 1 = manual, 2 = auto, 3+ = varies by driver
                            mode = FanControlMode.MANUAL if enable_value == 1 else FanControlMode.AUTO
                        except Exception:
                            pass

                    fans.append({
                        'name': f"{chip_name}/pwm{pwm_num}",
                        'chip': chip_name,
                        'pwm_path': str(pwm_file),
                        'pwm_enable_path': str(pwm_enable_file) if pwm_enable_file.exists() else None,
                        'fan_input_path': str(fan_input_file) if fan_input_file.exists() else None,
                        'current_pwm': current_pwm,
                        'current_rpm': current_rpm,
                        'mode': mode
                    })

                except Exception as e:
                    print(f"Error detecting PWM fan: {e}")

        return fans

    def _detect_gpu_fans(self) -> List[Dict]:
        """Detect GPU fans"""
        gpu_fans = []

        # NVIDIA GPUs
        try:
            result = subprocess.run(
                ["nvidia-smi", "--query-gpu=index,name", "--format=csv,noheader"],
                capture_output=True,
                text=True,
                timeout=3
            )

            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        parts = [p.strip() for p in line.split(',')]
                        gpu_index = int(parts[0])
                        gpu_name = parts[1] if len(parts) > 1 else f"GPU {gpu_index}"

                        gpu_fans.append({
                            'type': 'nvidia',
                            'index': gpu_index,
                            'name': f"{gpu_name} Fan"
                        })
        except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
            pass

        # AMD GPUs (via sysfs)
        drm_path = Path("/sys/class/drm")
        if drm_path.exists():
            for card_dir in sorted(drm_path.glob("card[0-9]*")):
                if "-" in card_dir.name:
                    continue

                device_dir = card_dir / "device"
                vendor_file = device_dir / "vendor"

                if vendor_file.exists():
                    vendor_id = vendor_file.read_text().strip()
                    if vendor_id == "0x1002":  # AMD
                        # Check if PWM control exists
                        hwmon_dir = device_dir / "hwmon"
                        if hwmon_dir.exists():
                            for hwmon_subdir in hwmon_dir.glob("hwmon*"):
                                pwm_files = list(hwmon_subdir.glob("pwm[0-9]"))
                                if pwm_files:
                                    gpu_fans.append({
                                        'type': 'amd',
                                        'name': f"AMD GPU {card_dir.name} Fan",
                                        'card_path': str(card_dir),
                                        'pwm_path': str(pwm_files[0])
                                    })

        return gpu_fans

    def get_fan_info(self, fan_index: int) -> Optional[FanInfo]:
        """Get information about a specific PWM fan"""
        if fan_index >= len(self.pwm_fans):
            return None

        fan = self.pwm_fans[fan_index]

        return FanInfo(
            name=fan['name'],
            current_speed=fan['current_rpm'],
            current_pwm=fan['current_pwm'],
            current_percent=int((fan['current_pwm'] / 255) * 100) if fan['current_pwm'] else None,
            pwm_path=fan['pwm_path'],
            pwm_enable_path=fan['pwm_enable_path'],
            mode=fan['mode']
        )

    def set_pwm_fan_speed(self, fan_index: int, percent: int) -> bool:
        """
        Set PWM fan speed (0-100%)

        Args:
            fan_index: Index of fan in self.pwm_fans
            percent: Fan speed percentage (0-100)

        Returns:
            True if successful, False otherwise
        """
        if fan_index >= len(self.pwm_fans):
            print(f"Fan index {fan_index} out of range")
            return False

        fan = self.pwm_fans[fan_index]

        # Clamp to 0-100%
        percent = max(0, min(100, percent))

        # Convert to PWM value (0-255)
        pwm_value = int((percent / 100) * 255)

        try:
            # First, set to manual mode if possible
            if fan['pwm_enable_path']:
                try:
                    with open(fan['pwm_enable_path'], 'w') as f:
                        f.write('1')  # 1 = manual mode
                except PermissionError:
                    print(f"Permission denied. Try running with sudo.")
                    return False

            # Set PWM value
            with open(fan['pwm_path'], 'w') as f:
                f.write(str(pwm_value))

            print(f"✅ Set {fan['name']} to {percent}% (PWM {pwm_value})")
            return True

        except PermissionError:
            print(f"❌ Permission denied. Run with sudo to control fans.")
            return False
        except Exception as e:
            print(f"❌ Error setting fan speed: {e}")
            return False

    def set_fan_auto(self, fan_index: int) -> bool:
        """Set fan to automatic mode"""
        if fan_index >= len(self.pwm_fans):
            return False

        fan = self.pwm_fans[fan_index]

        if not fan['pwm_enable_path']:
            print(f"Fan {fan['name']} doesn't support mode switching")
            return False

        try:
            with open(fan['pwm_enable_path'], 'w') as f:
                f.write('2')  # 2 = automatic mode

            print(f"✅ Set {fan['name']} to automatic mode")
            return True

        except PermissionError:
            print(f"❌ Permission denied. Run with sudo.")
            return False
        except Exception as e:
            print(f"❌ Error: {e}")
            return False

    def set_nvidia_gpu_fan(self, gpu_index: int, percent: int) -> bool:
        """
        Set NVIDIA GPU fan speed

        Args:
            gpu_index: GPU index (0, 1, etc.)
            percent: Fan speed percentage (0-100)

        Returns:
            True if successful
        """
        try:
            # Enable manual fan control
            subprocess.run([
                "nvidia-settings",
                "-a", f"[gpu:{gpu_index}]/GPUFanControlState=1"
            ], check=True, capture_output=True, timeout=5)

            # Set fan speed
            subprocess.run([
                "nvidia-settings",
                "-a", f"[fan:{gpu_index}]/GPUTargetFanSpeed={percent}"
            ], check=True, capture_output=True, timeout=5)

            print(f"✅ NVIDIA GPU {gpu_index} fan set to {percent}%")
            return True

        except FileNotFoundError:
            print("❌ nvidia-settings not found. Install it to control NVIDIA GPU fans.")
            return False
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to set NVIDIA GPU fan: {e}")
            return False
        except Exception as e:
            print(f"❌ Error: {e}")
            return False

    def set_nvidia_gpu_fan_auto(self, gpu_index: int) -> bool:
        """Set NVIDIA GPU fan to automatic mode"""
        try:
            subprocess.run([
                "nvidia-settings",
                "-a", f"[gpu:{gpu_index}]/GPUFanControlState=0"
            ], check=True, capture_output=True, timeout=5)

            print(f"✅ NVIDIA GPU {gpu_index} fan set to automatic")
            return True

        except Exception as e:
            print(f"❌ Error: {e}")
            return False

    def generate_report(self) -> str:
        """Generate fan control report"""
        lines = []
        lines.append("=" * 70)
        lines.append("💨 FAN CONTROLLER REPORT")
        lines.append("=" * 70)
        lines.append("")

        # PWM Fans
        if self.pwm_fans:
            lines.append(f"🌀 PWM Fans: {len(self.pwm_fans)}")
            lines.append("-" * 70)

            for i, fan in enumerate(self.pwm_fans):
                current_percent = int((fan['current_pwm'] / 255) * 100) if fan['current_pwm'] else 0
                mode_str = fan['mode'].value

                rpm_str = f"{fan['current_rpm']} RPM" if fan['current_rpm'] else "N/A"

                lines.append(f"  [{i}] {fan['name']}")
                lines.append(f"      Speed: {current_percent}% ({fan['current_pwm']}/255 PWM) - {rpm_str}")
                lines.append(f"      Mode: {mode_str}")
                lines.append(f"      Control: {fan['pwm_path']}")

            lines.append("")

        # GPU Fans
        if self.gpu_fans:
            lines.append(f"🎮 GPU Fans: {len(self.gpu_fans)}")
            lines.append("-" * 70)

            for fan in self.gpu_fans:
                lines.append(f"  • {fan['name']} ({fan['type'].upper()})")

            lines.append("")

        if not self.pwm_fans and not self.gpu_fans:
            lines.append("❌ No controllable fans detected")
            lines.append("")

        lines.append("=" * 70)
        return "\n".join(lines)


def main():
    """Test fan controller"""
    import sys

    controller = UniversalFanController()

    if len(sys.argv) < 2:
        print(controller.generate_report())
        print("\nUsage:")
        print("  python3 fan_controller.py status           - Show fan status")
        print("  python3 fan_controller.py set <fan> <pct>  - Set fan speed (0-100%)")
        print("  python3 fan_controller.py auto <fan>       - Set fan to automatic")
        print("  python3 fan_controller.py nvidia <gpu> <pct> - Set NVIDIA GPU fan")
        return

    command = sys.argv[1]

    if command == "status":
        print(controller.generate_report())

    elif command == "set" and len(sys.argv) >= 4:
        fan_index = int(sys.argv[2])
        percent = int(sys.argv[3])
        controller.set_pwm_fan_speed(fan_index, percent)

    elif command == "auto" and len(sys.argv) >= 3:
        fan_index = int(sys.argv[2])
        controller.set_fan_auto(fan_index)

    elif command == "nvidia" and len(sys.argv) >= 4:
        gpu_index = int(sys.argv[2])
        percent = int(sys.argv[3])
        controller.set_nvidia_gpu_fan(gpu_index, percent)

    else:
        print("Unknown command or missing arguments")


if __name__ == "__main__":
    main()
