#!/usr/bin/env python3

"""
CPU Frequency Manager - Core 2 Quad Q9550 Specific
Part of Power Management Suite
Handles CPU frequency scaling when BIOS/kernel methods fail
"""

import os
import sys
import subprocess
import time
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass
from enum import Enum

class FrequencyMethod(Enum):
    CPUFREQ = "cpufreq"           # Linux cpufreq subsystem
    MSR = "msr"                   # Direct MSR register access
    CPUPOWER = "cpupower"         # cpupower utility
    GRUB_FALLBACK = "grub"        # GRUB parameter modification

@dataclass
class CPUState:
    current_freq: int  # MHz
    min_freq: int      # MHz  
    max_freq: int      # MHz
    governor: str
    method: FrequencyMethod
    
class CPUFrequencyManager:
    """
    CPU Frequency Manager specifically designed for Core 2 Quad Q9550
    
    Handles multiple frequency control methods:
    1. Standard cpufreq (preferred)
    2. MSR register direct access (fallback)
    3. GRUB kernel parameter modification (persistent)
    """
    
    def __init__(self):
        self.cpu_model = self.detect_cpu_model()
        self.available_methods = self.detect_available_methods()
        self.active_method = None
        self.log_file = "/tmp/cpu_frequency_manager.log"
        
        # Q9550 specific frequency multipliers (MSR values)
        self.q9550_multipliers = {
            2833: 0x0615,  # 8.5x multiplier = 2833MHz  
            2500: 0x0513,  # 7.5x multiplier = 2500MHz
            2166: 0x0411,  # 6.5x multiplier = 2166MHz
            2000: 0x0610,  # 6.0x multiplier = 2000MHz
            1833: 0x050F,  # 5.5x multiplier = 1833MHz
            1666: 0x050E,  # 5.0x multiplier = 1666MHz
            1500: 0x050D,  # 4.5x multiplier = 1500MHz
            1333: 0x040C,  # 4.0x multiplier = 1333MHz
        }
        
    def log(self, message: str):
        timestamp = time.strftime("%H:%M:%S")
        log_msg = f"{timestamp} - {message}"
        print(log_msg)
        
        try:
            with open(self.log_file, "a") as f:
                f.write(log_msg + "\n")
        except:
            pass
    
    def detect_cpu_model(self) -> str:
        """Detect CPU model from /proc/cpuinfo"""
        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "model name" in line:
                        return line.split(":")[1].strip()
        except:
            pass
        return "Unknown"
    
    def detect_available_methods(self) -> List[FrequencyMethod]:
        """Detect which frequency control methods are available"""
        methods = []
        
        # Check cpufreq subsystem
        if Path("/sys/devices/system/cpu/cpu0/cpufreq").exists():
            methods.append(FrequencyMethod.CPUFREQ)
            
        # Check MSR access
        try:
            subprocess.run(["modprobe", "msr"], check=True, capture_output=True)
            if Path("/dev/cpu/0/msr").exists():
                methods.append(FrequencyMethod.MSR)
        except:
            pass
            
        # Check cpupower availability
        if subprocess.run(["which", "cpupower"], capture_output=True).returncode == 0:
            methods.append(FrequencyMethod.CPUPOWER)
            
        # GRUB is always available as last resort
        methods.append(FrequencyMethod.GRUB_FALLBACK)
        
        return methods
    
    def get_current_frequency(self) -> Optional[int]:
        """Get current CPU frequency in MHz"""
        
        # Method 1: /proc/cpuinfo
        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "cpu MHz" in line:
                        freq = float(line.split(":")[1].strip())
                        return int(freq)
        except:
            pass
            
        # Method 2: cpufreq 
        try:
            freq_path = "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq"
            if Path(freq_path).exists():
                with open(freq_path, "r") as f:
                    freq_khz = int(f.read().strip())
                    return freq_khz // 1000
        except:
            pass
            
        return None
    
    def set_frequency_cpufreq(self, target_freq: int) -> bool:
        """Set frequency using standard cpufreq interface"""
        try:
            # Set governor to userspace for manual control
            gov_path = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
            with open(gov_path, "w") as f:
                f.write("userspace")
                
            # Set frequency
            freq_path = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed"
            with open(freq_path, "w") as f:
                f.write(str(target_freq * 1000))  # Convert MHz to kHz
                
            self.log(f"✅ cpufreq: Set frequency to {target_freq}MHz")
            return True
            
        except Exception as e:
            self.log(f"❌ cpufreq failed: {e}")
            return False
    
    def set_frequency_msr(self, target_freq: int) -> bool:
        """Set frequency using direct MSR register access"""
        
        if target_freq not in self.q9550_multipliers:
            self.log(f"❌ MSR: Frequency {target_freq}MHz not supported")
            return False
            
        try:
            msr_value = self.q9550_multipliers[target_freq]
            
            # Load MSR module
            subprocess.run(["sudo", "modprobe", "msr"], check=True, capture_output=True)
            
            # Write to MSR register 0x199 (IA32_PERF_CTL)
            subprocess.run([
                "sudo", "wrmsr", "0x199", f"0x{msr_value:X}"
            ], check=True, capture_output=True)
            
            self.log(f"✅ MSR: Set frequency to {target_freq}MHz (MSR=0x{msr_value:X})")
            return True
            
        except Exception as e:
            self.log(f"❌ MSR failed: {e}")
            return False
    
    def set_frequency_cpupower(self, target_freq: int) -> bool:
        """Set frequency using cpupower utility"""
        try:
            result = subprocess.run([
                "sudo", "cpupower", "frequency-set", "-f", f"{target_freq}MHz"
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                self.log(f"✅ cpupower: Set frequency to {target_freq}MHz")
                return True
            else:
                self.log(f"❌ cpupower failed: {result.stderr}")
                return False
                
        except Exception as e:
            self.log(f"❌ cpupower error: {e}")
            return False
    
    def set_frequency(self, target_freq: int) -> bool:
        """Set CPU frequency using best available method"""
        
        for method in self.available_methods:
            if method == FrequencyMethod.CPUFREQ:
                if self.set_frequency_cpufreq(target_freq):
                    self.active_method = method
                    return True
                    
            elif method == FrequencyMethod.MSR:
                if self.set_frequency_msr(target_freq):
                    self.active_method = method
                    return True
                    
            elif method == FrequencyMethod.CPUPOWER:
                if self.set_frequency_cpupower(target_freq):
                    self.active_method = method
                    return True
        
        self.log(f"❌ All frequency control methods failed for {target_freq}MHz")
        return False
    
    def get_cpu_state(self) -> CPUState:
        """Get comprehensive CPU state information"""
        current_freq = self.get_current_frequency() or 0
        
        # Try to get governor
        governor = "unknown"
        try:
            gov_path = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
            if Path(gov_path).exists():
                with open(gov_path, "r") as f:
                    governor = f.read().strip()
        except:
            pass
            
        return CPUState(
            current_freq=current_freq,
            min_freq=1333,  # Q9550 minimum
            max_freq=2833,  # Q9550 maximum
            governor=governor,
            method=self.active_method or FrequencyMethod.MSR
        )
    
    def generate_grub_fix(self) -> str:
        """Generate GRUB configuration for persistent frequency control"""
        grub_params = [
            "intel_pstate=disable",
            "processor.max_cstate=1", 
            "acpi=force",
            "acpi_cpufreq.dyndbg=+p"
        ]
        
        grub_line = f'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash {" ".join(grub_params)}"'
        
        instructions = f"""
# GRUB Configuration Fix for CPU Frequency Control
# Add this line to /etc/default/grub:

{grub_line}

# Then run:
sudo update-grub
sudo reboot

# This will:
# - Disable intel_pstate (force acpi-cpufreq driver)  
# - Enable deeper C-states for power saving
# - Force ACPI support for older hardware
# - Enable cpufreq debugging
"""
        
        return instructions
    
    def thermal_profile_frequencies(self) -> Dict[str, int]:
        """Get recommended frequencies for different thermal profiles"""
        return {
            "performance": 2833,  # Maximum - only when cool
            "balanced": 2166,     # Good performance/thermal balance
            "power_save": 1666,   # Conservative for sustained workloads
            "emergency": 1333,    # Minimum for thermal emergencies
        }
    
    def status_report(self):
        """Generate comprehensive status report"""
        state = self.get_cpu_state()
        thermal_freqs = self.thermal_profile_frequencies()
        
        print("🔍 CPU Frequency Manager Status")
        print("=" * 35)
        print(f"🖥️  CPU Model: {self.cpu_model}")
        print(f"⚡ Current Frequency: {state.current_freq}MHz")
        print(f"📊 Governor: {state.governor}")
        print(f"🔧 Active Method: {state.method.value if state.method else 'None'}")
        print(f"🛠️  Available Methods: {[m.value for m in self.available_methods]}")
        print()
        print("🎯 Thermal Profile Frequencies:")
        for profile, freq in thermal_freqs.items():
            print(f"   {profile:12}: {freq}MHz")

def main():
    if len(sys.argv) < 2:
        print("Usage: cpu_frequency_manager.py {status|set <freq>|thermal <profile>|grub-fix}")
        sys.exit(1)
        
    manager = CPUFrequencyManager()
    command = sys.argv[1].lower()
    
    if command == "status":
        manager.status_report()
        
    elif command == "set" and len(sys.argv) >= 3:
        try:
            target_freq = int(sys.argv[2])
            if manager.set_frequency(target_freq):
                print(f"✅ Frequency set to {target_freq}MHz")
                time.sleep(1)  # Allow time for change
                manager.status_report()
            else:
                print(f"❌ Failed to set frequency to {target_freq}MHz")
                sys.exit(1)
        except ValueError:
            print("❌ Invalid frequency value")
            sys.exit(1)
            
    elif command == "thermal" and len(sys.argv) >= 3:
        profile = sys.argv[2].lower()
        thermal_freqs = manager.thermal_profile_frequencies()
        
        if profile in thermal_freqs:
            target_freq = thermal_freqs[profile]
            if manager.set_frequency(target_freq):
                print(f"✅ Thermal profile '{profile}' applied ({target_freq}MHz)")
            else:
                print(f"❌ Failed to apply thermal profile '{profile}'")
                sys.exit(1)
        else:
            print(f"❌ Unknown thermal profile: {profile}")
            print(f"Available profiles: {list(thermal_freqs.keys())}")
            sys.exit(1)
            
    elif command == "grub-fix":
        print(manager.generate_grub_fix())
        
    else:
        print("❌ Unknown command or missing arguments")
        sys.exit(1)

if __name__ == "__main__":
    main()