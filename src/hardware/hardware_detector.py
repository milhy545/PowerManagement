#!/usr/bin/env python3
"""
Universal Hardware Detector
Detects CPU, GPU, and thermal capabilities across different hardware platforms
Supports: Intel (old/new), AMD, various GPUs (AMD, NVIDIA, Intel)
"""

import os
import re
import subprocess
from pathlib import Path
from typing import Optional, Dict, List, Tuple
from dataclasses import dataclass
from enum import Enum


class CPUVendor(Enum):
    INTEL = "intel"
    AMD = "amd"
    UNKNOWN = "unknown"


class CPUGeneration(Enum):
    # Intel generations
    CORE2 = "core2"           # Core 2 Duo/Quad (2006-2011)
    NEHALEM = "nehalem"       # Core i3/i5/i7 1st gen (2008-2010)
    SANDY_BRIDGE = "sandybridge"  # 2nd gen (2011)
    IVY_BRIDGE = "ivybridge"     # 3rd gen (2012)
    HASWELL = "haswell"          # 4th gen (2013)
    BROADWELL = "broadwell"      # 5th gen (2014)
    SKYLAKE_PLUS = "skylake+"    # 6th gen+ (2015+)

    # AMD generations
    K8 = "k8"                 # Athlon 64, Opteron (2003-2008)
    K10 = "k10"               # Phenom (2007-2012)
    BULLDOZER = "bulldozer"   # FX series (2011-2017)
    ZEN = "zen"               # Ryzen (2017+)

    UNKNOWN = "unknown"


class GPUVendor(Enum):
    AMD = "amd"
    NVIDIA = "nvidia"
    INTEL = "intel"
    UNKNOWN = "unknown"


@dataclass
class CPUInfo:
    vendor: CPUVendor
    model_name: str
    generation: CPUGeneration
    cores: int
    min_freq_mhz: int
    max_freq_mhz: int
    current_freq_mhz: int
    supports_msr: bool
    supports_cpufreq: bool
    thermal_max_safe: int  # Maximum safe temperature in Celsius


@dataclass
class GPUInfo:
    vendor: GPUVendor
    model_name: str
    device_path: Optional[str]  # e.g., /sys/class/drm/card0
    supports_power_profile: bool
    supports_power_cap: bool


@dataclass
class ThermalInfo:
    zones: List[str]  # List of thermal zone paths
    current_temp: Optional[int]  # Current temperature in Celsius
    max_safe_temp: int  # Maximum safe temperature


class HardwareDetector:
    """Universal hardware detector for CPU, GPU, and thermal capabilities"""

    def __init__(self):
        self.cpu_info = self._detect_cpu()
        self.gpu_info = self._detect_gpu()
        self.thermal_info = self._detect_thermal()

    def _detect_cpu(self) -> CPUInfo:
        """Detect CPU information and capabilities"""
        vendor = CPUVendor.UNKNOWN
        model_name = "Unknown CPU"
        generation = CPUGeneration.UNKNOWN
        cores = 1

        # Read /proc/cpuinfo
        try:
            with open("/proc/cpuinfo", "r") as f:
                cpuinfo = f.read()

            # Extract model name
            model_match = re.search(r"model name\s*:\s*(.+)", cpuinfo)
            if model_match:
                model_name = model_match.group(1).strip()

            # Detect vendor
            if "Intel" in model_name:
                vendor = CPUVendor.INTEL
            elif "AMD" in model_name:
                vendor = CPUVendor.AMD

            # Count cores
            cores = len(re.findall(r"^processor\s*:", cpuinfo, re.MULTILINE))

            # Detect generation
            generation = self._detect_cpu_generation(vendor, model_name)

        except Exception as e:
            print(f"Warning: Failed to read /proc/cpuinfo: {e}")

        # Detect frequency range
        min_freq, max_freq = self._detect_frequency_range()
        current_freq = self._get_current_cpu_freq() or max_freq

        # Detect MSR support
        supports_msr = self._check_msr_support()

        # Detect cpufreq support
        supports_cpufreq = Path("/sys/devices/system/cpu/cpu0/cpufreq").exists()

        # Determine safe thermal max
        thermal_max = self._get_thermal_max_safe(vendor, generation)

        return CPUInfo(
            vendor=vendor,
            model_name=model_name,
            generation=generation,
            cores=cores,
            min_freq_mhz=min_freq,
            max_freq_mhz=max_freq,
            current_freq_mhz=current_freq,
            supports_msr=supports_msr,
            supports_cpufreq=supports_cpufreq,
            thermal_max_safe=thermal_max
        )

    def _detect_cpu_generation(self, vendor: CPUVendor, model_name: str) -> CPUGeneration:
        """Detect CPU generation from model name"""
        if vendor == CPUVendor.INTEL:
            # Core 2 series
            if re.search(r"Core\(TM\)2|Pentium\(R\) Dual", model_name):
                return CPUGeneration.CORE2
            # Core i-series by generation
            elif "i3-2" in model_name or "i5-2" in model_name or "i7-2" in model_name:
                return CPUGeneration.SANDY_BRIDGE
            elif "i3-3" in model_name or "i5-3" in model_name or "i7-3" in model_name:
                return CPUGeneration.IVY_BRIDGE
            elif "i3-4" in model_name or "i5-4" in model_name or "i7-4" in model_name:
                return CPUGeneration.HASWELL
            elif "i3-5" in model_name or "i5-5" in model_name or "i7-5" in model_name:
                return CPUGeneration.BROADWELL
            elif re.search(r"i[357]-[6-9]|i[357]-1[0-9]", model_name):
                return CPUGeneration.SKYLAKE_PLUS
            elif "i3" in model_name or "i5" in model_name or "i7" in model_name:
                return CPUGeneration.NEHALEM

        elif vendor == CPUVendor.AMD:
            if "Ryzen" in model_name or "EPYC" in model_name:
                return CPUGeneration.ZEN
            elif "FX" in model_name or "Bulldozer" in model_name:
                return CPUGeneration.BULLDOZER
            elif "Phenom" in model_name or "Athlon II" in model_name:
                return CPUGeneration.K10
            elif "Athlon 64" in model_name or "Opteron" in model_name:
                return CPUGeneration.K8

        return CPUGeneration.UNKNOWN

    def _detect_frequency_range(self) -> Tuple[int, int]:
        """Detect CPU frequency range (min, max) in MHz"""
        min_freq = 800  # Conservative default
        max_freq = 3000

        # Try cpufreq first
        try:
            cpuinfo_min = Path("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq")
            cpuinfo_max = Path("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")

            if cpuinfo_min.exists() and cpuinfo_max.exists():
                min_freq = int(cpuinfo_min.read_text().strip()) // 1000
                max_freq = int(cpuinfo_max.read_text().strip()) // 1000
                return min_freq, max_freq
        except Exception:
            pass

        # Fallback: parse /proc/cpuinfo for current freq and estimate
        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "cpu MHz" in line:
                        current = int(float(line.split(":")[1].strip()))
                        # Estimate range based on current frequency
                        max_freq = max(current, 2000)
                        min_freq = max_freq // 3  # Rough estimate
                        break
        except Exception:
            pass

        return min_freq, max_freq

    def _get_current_cpu_freq(self) -> Optional[int]:
        """Get current CPU frequency in MHz"""
        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "cpu MHz" in line:
                        return int(float(line.split(":")[1].strip()))
        except Exception:
            pass
        return None

    def _check_msr_support(self) -> bool:
        """Check if MSR (Model Specific Registers) are supported"""
        # Check if msr module can be loaded
        try:
            subprocess.run(["modprobe", "msr"], check=False, capture_output=True, timeout=2)
            return Path("/dev/cpu/0/msr").exists()
        except Exception:
            return False

    def _get_thermal_max_safe(self, vendor: CPUVendor, generation: CPUGeneration) -> int:
        """Get maximum safe temperature for CPU"""
        # Intel thermal limits
        if vendor == CPUVendor.INTEL:
            if generation == CPUGeneration.CORE2:
                return 85  # Core 2 series: ~85°C max
            elif generation in [CPUGeneration.NEHALEM, CPUGeneration.SANDY_BRIDGE]:
                return 95  # Older Core i: ~95°C
            else:
                return 100  # Modern Intel: ~100°C

        # AMD thermal limits
        elif vendor == CPUVendor.AMD:
            if generation in [CPUGeneration.K8, CPUGeneration.K10]:
                return 70  # Old AMD: lower limits
            elif generation == CPUGeneration.BULLDOZER:
                return 75
            else:
                return 95  # Modern AMD Ryzen

        return 85  # Conservative default

    def _detect_gpu(self) -> GPUInfo:
        """Detect GPU information"""
        vendor = GPUVendor.UNKNOWN
        model_name = "Unknown GPU"
        device_path = None
        supports_power_profile = False
        supports_power_cap = False

        # Search for GPU devices in /sys/class/drm
        drm_path = Path("/sys/class/drm")
        if drm_path.exists():
            for card_dir in drm_path.glob("card*"):
                # Skip card*-* (these are connectors, not cards)
                if "-" in card_dir.name:
                    continue

                device_dir = card_dir / "device"
                if not device_dir.exists():
                    continue

                # Try to identify vendor
                vendor_id = None
                try:
                    vendor_file = device_dir / "vendor"
                    if vendor_file.exists():
                        vendor_id = vendor_file.read_text().strip()
                except Exception:
                    pass

                # Determine vendor from ID
                if vendor_id:
                    if vendor_id == "0x1002":
                        vendor = GPUVendor.AMD
                    elif vendor_id in ["0x10de", "0x10DE"]:
                        vendor = GPUVendor.NVIDIA
                    elif vendor_id == "0x8086":
                        vendor = GPUVendor.INTEL

                # Try to get model name
                try:
                    uevent_file = device_dir / "uevent"
                    if uevent_file.exists():
                        uevent = uevent_file.read_text()
                        pci_id_match = re.search(r"PCI_ID=([0-9A-Fa-f:]+)", uevent)
                        if pci_id_match:
                            model_name = f"GPU {pci_id_match.group(1)}"
                except Exception:
                    pass

                # Check power management capabilities
                power_profile = device_dir / "power_profile"
                power_cap = device_dir / "hwmon" / "hwmon0" / "power1_cap"

                if power_profile.exists():
                    supports_power_profile = True
                    device_path = str(card_dir)
                    break  # Use first GPU with power_profile support

                if power_cap.exists():
                    supports_power_cap = True
                    if not device_path:
                        device_path = str(card_dir)

        # Fallback: Try lspci
        if vendor == GPUVendor.UNKNOWN:
            try:
                result = subprocess.run(
                    ["lspci", "-nn"],
                    capture_output=True,
                    text=True,
                    timeout=2
                )
                for line in result.stdout.splitlines():
                    if "VGA" in line or "3D controller" in line:
                        if "AMD" in line or "ATI" in line:
                            vendor = GPUVendor.AMD
                            model_name = line.split(":", 1)[1].strip()
                            break
                        elif "NVIDIA" in line:
                            vendor = GPUVendor.NVIDIA
                            model_name = line.split(":", 1)[1].strip()
                            break
                        elif "Intel" in line:
                            vendor = GPUVendor.INTEL
                            model_name = line.split(":", 1)[1].strip()
                            break
            except Exception:
                pass

        return GPUInfo(
            vendor=vendor,
            model_name=model_name,
            device_path=device_path,
            supports_power_profile=supports_power_profile,
            supports_power_cap=supports_power_cap
        )

    def _detect_thermal(self) -> ThermalInfo:
        """Detect thermal monitoring capabilities"""
        zones = []
        current_temp = None

        # Find all thermal zones
        thermal_base = Path("/sys/class/thermal")
        if thermal_base.exists():
            for zone in thermal_base.glob("thermal_zone*"):
                temp_file = zone / "temp"
                if temp_file.exists():
                    zones.append(str(temp_file))

                    # Read temperature from first zone
                    if current_temp is None:
                        try:
                            temp_millidegrees = int(temp_file.read_text().strip())
                            current_temp = temp_millidegrees // 1000
                        except Exception:
                            pass

        # Use CPU thermal max as system thermal max
        max_safe_temp = self.cpu_info.thermal_max_safe

        return ThermalInfo(
            zones=zones,
            current_temp=current_temp,
            max_safe_temp=max_safe_temp
        )

    def generate_report(self) -> str:
        """Generate human-readable hardware report"""
        report = []
        report.append("=" * 60)
        report.append("🔍 HARDWARE DETECTION REPORT")
        report.append("=" * 60)
        report.append("")

        # CPU Info
        report.append("🖥️  CPU INFORMATION:")
        report.append(f"   Vendor: {self.cpu_info.vendor.value.upper()}")
        report.append(f"   Model: {self.cpu_info.model_name}")
        report.append(f"   Generation: {self.cpu_info.generation.value}")
        report.append(f"   Cores: {self.cpu_info.cores}")
        report.append(f"   Frequency: {self.cpu_info.min_freq_mhz}-{self.cpu_info.max_freq_mhz} MHz (current: {self.cpu_info.current_freq_mhz} MHz)")
        report.append(f"   MSR Support: {'✅ Yes' if self.cpu_info.supports_msr else '❌ No'}")
        report.append(f"   CPUFreq Support: {'✅ Yes' if self.cpu_info.supports_cpufreq else '❌ No'}")
        report.append(f"   Thermal Max Safe: {self.cpu_info.thermal_max_safe}°C")
        report.append("")

        # GPU Info
        report.append("🎮 GPU INFORMATION:")
        report.append(f"   Vendor: {self.gpu_info.vendor.value.upper()}")
        report.append(f"   Model: {self.gpu_info.model_name}")
        report.append(f"   Device Path: {self.gpu_info.device_path or 'Not found'}")
        report.append(f"   Power Profile Support: {'✅ Yes' if self.gpu_info.supports_power_profile else '❌ No'}")
        report.append(f"   Power Cap Support: {'✅ Yes' if self.gpu_info.supports_power_cap else '❌ No'}")
        report.append("")

        # Thermal Info
        report.append("🌡️  THERMAL INFORMATION:")
        report.append(f"   Thermal Zones: {len(self.thermal_info.zones)}")
        if self.thermal_info.current_temp:
            report.append(f"   Current Temperature: {self.thermal_info.current_temp}°C")
        report.append(f"   Maximum Safe Temp: {self.thermal_info.max_safe_temp}°C")
        report.append("")

        report.append("=" * 60)

        return "\n".join(report)

    def is_compatible(self) -> Tuple[bool, List[str]]:
        """Check if hardware is compatible with power management"""
        compatible = True
        issues = []

        # Check CPU support
        if not self.cpu_info.supports_cpufreq and not self.cpu_info.supports_msr:
            compatible = False
            issues.append("❌ No CPU frequency control available (neither cpufreq nor MSR)")
        elif not self.cpu_info.supports_cpufreq:
            issues.append("⚠️  CPUFreq not available, will use MSR (requires root)")

        # Check thermal
        if not self.thermal_info.zones:
            issues.append("⚠️  No thermal zones found - temperature monitoring disabled")

        # GPU is optional
        if not self.gpu_info.supports_power_profile and not self.gpu_info.supports_power_cap:
            issues.append("ℹ️  GPU power management not available (optional)")

        if compatible:
            issues.insert(0, "✅ Hardware is compatible with power management")

        return compatible, issues


def main():
    """Test hardware detection"""
    detector = HardwareDetector()
    print(detector.generate_report())

    compatible, issues = detector.is_compatible()
    print("\n🔍 COMPATIBILITY CHECK:")
    for issue in issues:
        print(f"  {issue}")

    if not compatible:
        print("\n❌ Hardware not fully compatible - some features may not work")
        return 1
    else:
        print("\n✅ All systems ready for power management!")
        return 0


if __name__ == "__main__":
    exit(main())
