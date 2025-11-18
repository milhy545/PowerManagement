#!/usr/bin/env python3
"""
Universal CPU Frequency Manager
Works across different CPU models: Intel (Core 2, Core i-series), AMD (Phenom, FX, Ryzen)
Automatically detects hardware and uses appropriate frequency control methods
"""

import os
import sys
import subprocess
import time
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass

# Add parent directory to path to import hardware detector
sys.path.insert(0, str(Path(__file__).parent.parent))

from hardware.hardware_detector import (
    HardwareDetector, CPUVendor, CPUGeneration
)
from config.power_config import PowerConfig


@dataclass
class FrequencyProfile:
    """Frequency profile for different power modes"""
    name: str
    frequency_mhz: int
    description: str


class UniversalCPUManager:
    """
    Universal CPU Frequency Manager
    Supports:
    - Intel: Core 2, Nehalem, Sandy Bridge, Ivy Bridge, Haswell, Broadwell, Skylake+
    - AMD: K8, K10, Bulldozer, Zen
    - Multiple control methods: cpufreq, MSR, cpupower
    """

    # Intel Core 2 Quad MSR multipliers (for legacy support)
    CORE2_QUAD_MULTIPLIERS = {
        # Q9550, Q9650, Q9450, etc.
        2833: 0x0615,  # 8.5x
        2666: 0x0514,  # 8.0x
        2500: 0x0513,  # 7.5x
        2333: 0x0512,  # 7.0x
        2166: 0x0411,  # 6.5x
        2000: 0x0610,  # 6.0x
        1833: 0x050F,  # 5.5x
        1666: 0x050E,  # 5.0x
        1500: 0x050D,  # 4.5x
        1333: 0x040C,  # 4.0x
        1200: 0x040B,  # 3.6x
    }

    def __init__(self):
        """Initialize universal CPU manager with hardware detection"""
        self.is_ci = os.environ.get('CI', 'false').lower() == 'true'

        # Detect hardware
        self.detector = HardwareDetector()
        self.cpu_info = self.detector.cpu_info

        # Load configuration
        self.config = PowerConfig()
        self.config.set_frequency_config(
            self.cpu_info.min_freq_mhz,
            self.cpu_info.max_freq_mhz
        )
        self.config.set_thermal_config(self.cpu_info.thermal_max_safe)

        # Setup logging
        self.log_file = self.config.paths.cpu_log

        # Determine best control method
        self.control_method = self._select_control_method()

        self.log(f"✅ Initialized for {self.cpu_info.vendor.value.upper()} "
                 f"{self.cpu_info.generation.value} CPU")
        self.log(f"   Control method: {self.control_method}")

    def log(self, message: str):
        """Log message to file and stdout"""
        timestamp = time.strftime("%H:%M:%S")
        log_msg = f"{timestamp} - {message}"
        print(log_msg)

        try:
            with open(self.log_file, "a") as f:
                f.write(log_msg + "\n")
        except Exception:
            pass

    def _select_control_method(self) -> str:
        """Select best frequency control method for this hardware"""
        if self.is_ci:
            return "CI_MODE"

        # Prefer cpufreq for modern systems
        if self.cpu_info.supports_cpufreq:
            # Modern Intel (Skylake+) uses intel_pstate, others use acpi-cpufreq
            if self.cpu_info.generation == CPUGeneration.SKYLAKE_PLUS:
                return "cpufreq_intel_pstate"
            return "cpufreq"

        # Fallback to MSR for older systems
        if self.cpu_info.supports_msr:
            return "msr"

        # Last resort: cpupower command
        try:
            result = subprocess.run(["which", "cpupower"], capture_output=True)
            if result.returncode == 0:
                return "cpupower"
        except Exception:
            pass

        return "none"

    def get_frequency_profiles(self) -> List[FrequencyProfile]:
        """Get frequency profiles for this CPU"""
        if not self.config.frequency:
            return []

        return [
            FrequencyProfile(
                "performance",
                self.config.frequency.performance_freq,
                "Maximum performance - full CPU speed"
            ),
            FrequencyProfile(
                "balanced",
                self.config.frequency.balanced_freq,
                "Balanced - good performance with moderate power"
            ),
            FrequencyProfile(
                "powersave",
                self.config.frequency.powersave_freq,
                "Power saving - reduced speed for efficiency"
            ),
            FrequencyProfile(
                "emergency",
                self.config.frequency.emergency_freq,
                "Emergency - minimum speed to prevent thermal shutdown"
            ),
        ]

    def set_frequency_cpufreq(self, target_freq: int) -> bool:
        """Set frequency using cpufreq subsystem"""
        try:
            # For intel_pstate, use scaling_max_freq and scaling_min_freq
            if self.control_method == "cpufreq_intel_pstate":
                for cpu_id in range(self.cpu_info.cores):
                    base = f"/sys/devices/system/cpu/cpu{cpu_id}/cpufreq"

                    # Set both min and max to target (forces frequency)
                    with open(f"{base}/scaling_min_freq", "w") as f:
                        f.write(str(target_freq * 1000))
                    with open(f"{base}/scaling_max_freq", "w") as f:
                        f.write(str(target_freq * 1000))

                self.log(f"✅ intel_pstate: Set to {target_freq}MHz")
                return True

            # For acpi-cpufreq, use userspace governor
            else:
                for cpu_id in range(self.cpu_info.cores):
                    base = f"/sys/devices/system/cpu/cpu{cpu_id}/cpufreq"

                    # Set governor to userspace
                    with open(f"{base}/scaling_governor", "w") as f:
                        f.write("userspace")

                    # Set frequency
                    with open(f"{base}/scaling_setspeed", "w") as f:
                        f.write(str(target_freq * 1000))

                self.log(f"✅ cpufreq: Set to {target_freq}MHz")
                return True

        except PermissionError:
            self.log("❌ cpufreq: Permission denied (need root)")
            return False
        except Exception as e:
            self.log(f"❌ cpufreq failed: {e}")
            return False

    def set_frequency_msr(self, target_freq: int) -> bool:
        """Set frequency using MSR (for older CPUs)"""
        # Only Core 2 Quad has known MSR multipliers
        if self.cpu_info.generation != CPUGeneration.CORE2:
            self.log("⚠️  MSR: No multiplier table for this CPU generation")
            return False

        # Find closest frequency in multiplier table
        available_freqs = sorted(self.CORE2_QUAD_MULTIPLIERS.keys())
        closest_freq = min(available_freqs, key=lambda x: abs(x - target_freq))

        if abs(closest_freq - target_freq) > 200:
            self.log(f"⚠️  MSR: Target {target_freq}MHz too far from available frequencies")
            return False

        try:
            msr_value = self.CORE2_QUAD_MULTIPLIERS[closest_freq]

            # Load MSR module
            subprocess.run(["sudo", "modprobe", "msr"],
                          check=True, capture_output=True, timeout=5)

            # Write to IA32_PERF_CTL register (0x199)
            subprocess.run([
                "sudo", "wrmsr", "-a", "0x199", f"0x{msr_value:X}"
            ], check=True, capture_output=True, timeout=5)

            self.log(f"✅ MSR: Set to {closest_freq}MHz (MSR=0x{msr_value:X})")
            return True

        except subprocess.TimeoutExpired:
            self.log("❌ MSR: Command timeout")
            return False
        except Exception as e:
            self.log(f"❌ MSR failed: {e}")
            return False

    def set_frequency_cpupower(self, target_freq: int) -> bool:
        """Set frequency using cpupower utility"""
        try:
            result = subprocess.run([
                "sudo", "cpupower", "frequency-set", "-f", f"{target_freq}MHz"
            ], capture_output=True, text=True, timeout=10)

            if result.returncode == 0:
                self.log(f"✅ cpupower: Set to {target_freq}MHz")
                return True
            else:
                self.log(f"❌ cpupower failed: {result.stderr}")
                return False

        except Exception as e:
            self.log(f"❌ cpupower error: {e}")
            return False

    def set_frequency(self, target_freq: int) -> bool:
        """Set CPU frequency using best available method"""
        if self.is_ci:
            self.log(f"CI Mode: Simulating frequency set to {target_freq}MHz")
            return True

        # Clamp to valid range
        target_freq = max(self.cpu_info.min_freq_mhz,
                         min(target_freq, self.cpu_info.max_freq_mhz))

        # Try selected control method
        if self.control_method in ["cpufreq", "cpufreq_intel_pstate"]:
            return self.set_frequency_cpufreq(target_freq)
        elif self.control_method == "msr":
            return self.set_frequency_msr(target_freq)
        elif self.control_method == "cpupower":
            return self.set_frequency_cpupower(target_freq)
        else:
            self.log("❌ No frequency control method available")
            return False

    def set_profile(self, profile_name: str) -> bool:
        """Set frequency by profile name"""
        profiles = {p.name: p for p in self.get_frequency_profiles()}

        if profile_name not in profiles:
            self.log(f"❌ Unknown profile: {profile_name}")
            return False

        profile = profiles[profile_name]
        self.log(f"🎯 Applying profile: {profile.name} ({profile.description})")
        return self.set_frequency(profile.frequency_mhz)

    def get_current_frequency(self) -> Optional[int]:
        """Get current CPU frequency in MHz"""
        try:
            # Try /proc/cpuinfo first
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "cpu MHz" in line:
                        return int(float(line.split(":")[1].strip()))
        except Exception:
            pass

        # Try cpufreq
        try:
            with open("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq", "r") as f:
                return int(f.read().strip()) // 1000
        except Exception:
            pass

        return None

    def status_report(self):
        """Generate status report"""
        current_freq = self.get_current_frequency()

        print("=" * 60)
        print("⚡ UNIVERSAL CPU FREQUENCY MANAGER - STATUS")
        print("=" * 60)
        print()
        print(f"🖥️  CPU: {self.cpu_info.model_name}")
        print(f"📊 Vendor: {self.cpu_info.vendor.value.upper()}")
        print(f"🔧 Generation: {self.cpu_info.generation.value}")
        print(f"💾 Cores: {self.cpu_info.cores}")
        print()
        print(f"⚡ Current Frequency: {current_freq or 'Unknown'} MHz")
        print(f"📈 Frequency Range: {self.cpu_info.min_freq_mhz}-{self.cpu_info.max_freq_mhz} MHz")
        print(f"🔌 Control Method: {self.control_method}")
        print()
        print("🎯 Available Profiles:")
        for profile in self.get_frequency_profiles():
            print(f"   • {profile.name:12} : {profile.frequency_mhz:4} MHz - {profile.description}")
        print()
        print("=" * 60)


def main():
    """Main CLI interface"""
    if len(sys.argv) < 2:
        print("Usage: universal_cpu_manager.py {status|set <freq>|profile <name>|detect}")
        print()
        print("Commands:")
        print("  status                 - Show current status")
        print("  set <freq>            - Set frequency in MHz")
        print("  profile <name>        - Set profile (performance/balanced/powersave/emergency)")
        print("  detect                - Show hardware detection info")
        sys.exit(1)

    manager = UniversalCPUManager()
    command = sys.argv[1].lower()

    if command == "status":
        manager.status_report()

    elif command == "detect":
        print(manager.detector.generate_report())

    elif command == "set" and len(sys.argv) >= 3:
        try:
            target_freq = int(sys.argv[2])
            if manager.set_frequency(target_freq):
                print(f"✅ Frequency set to {target_freq}MHz")
                time.sleep(1)
                manager.status_report()
            else:
                print(f"❌ Failed to set frequency")
                sys.exit(1)
        except ValueError:
            print("❌ Invalid frequency value")
            sys.exit(1)

    elif command == "profile" and len(sys.argv) >= 3:
        profile_name = sys.argv[2].lower()
        if manager.set_profile(profile_name):
            print(f"✅ Profile '{profile_name}' applied")
            time.sleep(1)
            manager.status_report()
        else:
            print(f"❌ Failed to apply profile '{profile_name}'")
            sys.exit(1)

    else:
        print("❌ Unknown command or missing arguments")
        sys.exit(1)


if __name__ == "__main__":
    main()
