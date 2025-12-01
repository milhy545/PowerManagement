# Linux Power Management Suite - Development Guidelines

## Code Quality Standards

### File Headers and Documentation
Every file MUST include a comprehensive docstring header:
```python
#!/usr/bin/env python3

"""
Module Name - Brief Description
Part of Power Management Suite
Detailed purpose and functionality explanation
"""
```

For shell scripts:
```bash
#!/bin/bash

# Script Name - Brief Description
# Part of Power Management Suite
# Detailed purpose and functionality
```

### Naming Conventions
- **Python Files**: snake_case (e.g., `cpu_frequency_manager.py`, `smart_thermal_manager.py`)
- **Shell Scripts**: snake_case with .sh extension (e.g., `performance_manager.sh`, `ai_process_manager.sh`)
- **Classes**: PascalCase (e.g., `CPUFrequencyManager`, `SmartThermalManager`, `ThermalMyCoder`)
- **Functions/Methods**: snake_case (e.g., `get_cpu_temperature`, `thermal_safety_check`, `set_power_profile`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `DBUS_SERVICE`, `MAX_PROCESSES`, `EMERGENCY_TIMEOUT`)
- **Variables**: snake_case (e.g., `current_freq`, `temp_threshold`, `session_count`)

### Import Organization
Python imports MUST be organized in this order:
1. Standard library imports
2. Third-party library imports
3. Local module imports

```python
# Standard library
import os
import sys
import time
import subprocess
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass
from enum import Enum

# Third-party
import psutil
import aiohttp
import dbus

# Local (if any)
from .utils import helper_function
```

### Logging Standards
All scripts MUST implement consistent logging:

**Python logging pattern:**
```python
def log(self, message: str):
    timestamp = time.strftime("%H:%M:%S")
    log_msg = f"{timestamp} - {message}"
    print(log_msg)
    
    try:
        with open(self.log_file, "a") as f:
            f.write(log_msg + "\n")
    except:
        pass
```

**Logging format with emojis for clarity:**
- ✅ Success operations
- ❌ Failures and errors
- ⚠️ Warnings
- 🌡️ Temperature readings
- 🔥 Performance mode
- ⚖️ Balanced mode
- 🔋 Power save mode
- 🚨 Emergency/critical situations
- 🤖 AI-related operations
- 📊 Status information

## Structural Conventions

### Dataclasses for State Management
Use dataclasses for structured state representation:
```python
from dataclasses import dataclass

@dataclass
class CPUState:
    current_freq: int  # MHz
    min_freq: int      # MHz  
    max_freq: int      # MHz
    governor: str
    method: FrequencyMethod

@dataclass
class SystemStatus:
    cpu_temp: int
    cpu_usage: float
    load_avg: float
    power_mode: PowerMode
```

### Enums for Fixed Options
Use Enum classes for predefined options:
```python
from enum import Enum

class PowerMode(Enum):
    PERFORMANCE = "performance"
    BALANCED = "balanced" 
    POWER_SAVE = "power-saver"
    EMERGENCY = "emergency"

class FrequencyMethod(Enum):
    CPUFREQ = "cpufreq"
    MSR = "msr"
    CPUPOWER = "cpupower"
    GRUB_FALLBACK = "grub"
```

### Type Hints
All Python functions MUST include type hints:
```python
def get_current_frequency(self) -> Optional[int]:
    """Get current CPU frequency in MHz"""
    # Implementation

def set_frequency(self, target_freq: int) -> bool:
    """Set CPU frequency using best available method"""
    # Implementation

def thermal_profile_frequencies(self) -> Dict[str, int]:
    """Get recommended frequencies for different thermal profiles"""
    # Implementation
```

## Safety-First Design Patterns

### CI Environment Detection
Always detect and handle CI environments:
```python
def __init__(self):
    # Detect CI environment
    self.is_ci = os.environ.get('CI', 'false').lower() == 'true'
    
    if self.is_ci:
        self.log("Running in CI mode - hardware access limited")
```

### Timeout Protection
All subprocess calls MUST include timeouts:
```python
# Good - with timeout
subprocess.run(["sensors"], capture_output=True, text=True, timeout=3)

# Good - with timeout and error handling
try:
    result = subprocess.run(
        ["sudo", "cpupower", "frequency-set", "-f", f"{target_freq}MHz"],
        capture_output=True, text=True, timeout=10
    )
except subprocess.TimeoutExpired:
    self.log("❌ Operation timeout")
    return False
```

### Graceful Error Handling
Never let exceptions crash the program:
```python
def get_cpu_temperature(self) -> Optional[int]:
    """Get CPU temperature using multiple methods"""
    # Method 1: sensors command
    try:
        result = subprocess.run(["sensors"], capture_output=True, text=True, timeout=3)
        for line in result.stdout.split('\n'):
            if "Core 0:" in line and "+" in line:
                temp_str = line.split('+')[1].split('°')[0]
                return int(float(temp_str))
    except:
        pass
        
    # Method 2: thermal_zone (fallback)
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
            temp = int(f.read().strip()) // 1000
            return temp
    except:
        pass
        
    return None  # Return None if all methods fail
```

### Multiple Fallback Methods
Implement multiple methods with fallback chain:
```python
def set_frequency(self, target_freq: int) -> bool:
    """Set CPU frequency using best available method"""
    
    # In CI mode, simulate success
    if self.is_ci:
        self.log(f"CI Mode: Simulating frequency set to {target_freq}MHz")
        return True
    
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
```

## Thermal Management Patterns

### Progressive Thermal Response
Implement graduated thermal responses:
```python
def adaptive_thermal_response(self, temp: int, cpu_usage: float):
    """
    Adaptive thermal response with progressive escalation:
    - Below 65°C: Performance OK
    - 65-70°C: Start throttling AI
    - 70-80°C: Progressive escalation
    - 80°C+: Emergency measures
    """
    
    if temp < self.comfort_temp:
        # System cool - can run performance mode
        if self.current_mode == PowerMode.EMERGENCY:
            self.set_power_profile(PowerMode.BALANCED)
            self.escalation_count = max(0, self.escalation_count - 1)
            
    elif temp < self.warning_temp:
        # Slight warming - preventive throttling
        if self.current_mode == PowerMode.PERFORMANCE:
            self.set_power_profile(PowerMode.BALANCED)
            self.throttle_ai_processes(nice_level=5)
            
    elif temp < self.critical_temp:
        # Warning zone - progressive throttling
        self.escalation_count += 1
        
        if self.escalation_count <= 3:
            self.set_power_profile(PowerMode.POWER_SAVE)
            self.throttle_ai_processes(nice_level=10 + (self.escalation_count * 2))
            self.log(f"⚠️ {temp}°C - Progressive throttling level {self.escalation_count}")
        else:
            self.set_power_profile(PowerMode.EMERGENCY)
            self.throttle_ai_processes(nice_level=19)
            
    elif temp >= self.emergency_temp:
        # Critical - immediate emergency stop
        self.log(f"🚨 CRITICAL {temp}°C - Emergency shutdown!")
        self.set_power_profile(PowerMode.EMERGENCY)
        self.emergency_kill_heavy_processes()
        self.escalation_count = 10
```

### Thermal Safety Checks
Always check temperature before intensive operations:
```python
def thermal_safety_check(self) -> bool:
    """Kontrola thermal safety"""
    temp = self.get_cpu_temperature()
    if not temp:
        print("⚠️ Cannot read temperature!")
        return False
        
    cpu_usage = psutil.cpu_percent(interval=0.5)
    print(f"🌡️ {temp}°C | CPU: {cpu_usage}%", end="")
    
    if temp >= self.critical_temp:
        print(f" 🚨 CRITICAL!")
        self.emergency_thermal_stop()
        return False
        
    if temp >= self.temp_threshold:
        print(f" ⚠️ HOT! Cooling...")
        time.sleep(15)
        return self.thermal_safety_check()  # Recursive check
        
    print(" ✅ Safe")
    return True
```

## Process Management Patterns

### CPU Core Affinity
Limit process CPU usage by core affinity:
```python
def limit_cpu_cores(self):
    """Omez proces na 2 jádra"""
    try:
        current_process = psutil.Process()
        current_process.cpu_affinity([0, 1])
        # Set lowest priority
        current_process.nice(19)
        print("✅ Process: 2 cores, lowest priority")
    except Exception as e:
        print(f"⚠️ CPU limiting failed: {e}")
```

### Process Priority Control
Use renice for process priority adjustment:
```python
def throttle_ai_processes(self, nice_level: int = 10):
    """Throttle AI processes to reduce CPU load"""
    ai_pids = self.find_ai_processes()
    throttled = 0
    
    for pid in ai_pids:
        try:
            # Set process priority
            subprocess.run(["sudo", "renice", f"+{nice_level}", str(pid)], 
                         check=False, timeout=2)
            
            # Limit to specific CPU cores
            if nice_level > 15:  # Emergency mode
                subprocess.run(["sudo", "taskset", "-cp", "0", str(pid)], 
                             check=False, timeout=2)
            elif nice_level > 5:  # Warning mode  
                subprocess.run(["sudo", "taskset", "-cp", "0,1", str(pid)], 
                             check=False, timeout=2)
            
            throttled += 1
        except:
            continue
            
    if throttled > 0:
        self.log(f"🎛️ Throttled {throttled} AI processes (nice +{nice_level})")
        
    return throttled
```

### Emergency Process Termination
Implement emergency cleanup procedures:
```python
def emergency_kill_heavy_processes(self):
    """Emergency process termination"""
    self.log("🚨 EMERGENCY: Killing heavy processes")
    
    heavy_patterns = ["docker", "ollama", "python.*ollama", "npm", "python.*mycoder"]
    
    for pattern in heavy_patterns:
        try:
            subprocess.run(["pkill", "-f", pattern], check=False, timeout=3)
        except:
            continue
            
    # Clear memory
    try:
        subprocess.run(["sudo", "sync"], check=False, timeout=5)
        subprocess.run(["sudo", "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"], 
                     check=False, timeout=5)
    except:
        pass
        
    self.log("🛑 Emergency cleanup completed")
```

## Async/Await Patterns for AI Workloads

### Async AI Generation
Use async/await for non-blocking AI operations:
```python
async def ai_generate(self, prompt: str, max_tokens: int = 150) -> Optional[str]:
    """Skutečné AI generování s thermal protection"""
    
    # Pre-generation safety check
    if not self.thermal_safety_check():
        return None
        
    print(f"🤖 Generating with {self.model_name}...")
    
    payload = {
        "model": self.model_name,
        "prompt": prompt,
        "options": {
            "num_predict": max_tokens,
            "temperature": 0.3,
            "top_p": 0.9,
            "num_ctx": 1024,
        },
        "stream": False
    }
    
    try:
        async with aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30)
        ) as session:
            
            start_temp = self.get_cpu_temperature()
            
            async with session.post(
                f"{self.ollama_url}/api/generate", 
                json=payload
            ) as response:
                
                if response.status == 200:
                    result = await response.json()
                    
                    # Post-generation safety check
                    end_temp = self.get_cpu_temperature()
                    if end_temp and start_temp:
                        temp_rise = end_temp - start_temp
                        print(f"🌡️ Temperature rise: +{temp_rise}°C")
                        
                        if temp_rise > 5:
                            print("⚠️ Significant temperature rise - cooling down")
                            time.sleep(10)
                    
                    return result.get('response', '').strip()
                else:
                    print(f"❌ AI request failed: {response.status}")
                    return None
                    
    except asyncio.TimeoutError:
        print("⏰ AI generation timeout")
        return None
    except Exception as e:
        print(f"❌ AI generation error: {e}")
        return None
```

## D-Bus Integration Patterns

### D-Bus Service Implementation
Implement D-Bus services for system integration:
```python
class CustomPowerProfilesDaemon(dbus.service.Object):
    """
    Custom Power Profiles Daemon
    Compatible D-Bus interface with enhanced functionality
    """
    
    DBUS_SERVICE = 'net.hadess.PowerProfiles'
    DBUS_PATH = '/net/hadess/PowerProfiles'
    DBUS_INTERFACE = 'net.hadess.PowerProfiles'
    
    def __init__(self):
        # D-Bus setup
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        bus_name = dbus.service.BusName(self.DBUS_SERVICE, self.bus)
        dbus.service.Object.__init__(self, bus_name, self.DBUS_PATH)
        
        # State initialization
        self.active_profile = "balanced"
        self.profiles = [...]
        
    @dbus.service.method(DBUS_INTERFACE, in_signature='', out_signature='s') 
    def GetActiveProfile(self):
        """Get current active profile"""
        return self.active_profile
        
    @dbus.service.method(DBUS_INTERFACE, in_signature='s', out_signature='')
    def SetActiveProfile(self, profile):
        """Set active profile"""
        if profile in [p["Profile"] for p in self.profiles]:
            old_profile = self.active_profile
            self.active_profile = profile
            
            # Execute profile change
            self._execute_profile_change(profile)
            
            # Emit D-Bus signal
            self.PropertiesChanged(
                self.DBUS_INTERFACE,
                {"ActiveProfile": profile},
                []
            )
```

## Command-Line Interface Patterns

### Argument Parsing
Implement clear command-line interfaces:
```python
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
```

## Status Reporting Patterns

### Comprehensive Status Reports
Provide detailed, formatted status information:
```python
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
```

## Testing and Validation

### Dry Run Mode
Always implement test/dry-run modes:
```python
def __init__(self):
    self.is_ci = os.environ.get('CI', 'false').lower() == 'true'
    self.dry_run = os.environ.get('DRY_RUN', 'false').lower() == 'true'
    
    if self.dry_run:
        self.log("Running in DRY RUN mode - no actual changes")

def set_frequency(self, target_freq: int) -> bool:
    if self.dry_run:
        self.log(f"DRY RUN: Would set frequency to {target_freq}MHz")
        return True
    
    # Actual implementation
    ...
```

## Hardware-Specific Patterns

### Hardware Detection
Detect and adapt to specific hardware:
```python
def __init__(self):
    self.cpu_model = self.detect_cpu_model()
    
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
```

## Configuration Constants

### Centralized Configuration
Define configuration constants at class level:
```python
class SmartThermalManager:
    def __init__(self):
        # Thermal thresholds
        self.comfort_temp = 65    # Below this = performance OK
        self.warning_temp = 70    # Start throttling
        self.critical_temp = 80   # Emergency measures
        self.emergency_temp = 83  # Shutdown threshold
        
        # Timeouts
        self.operation_timeout = 10
        self.sensor_timeout = 3
        
        # Paths
        self.log_file = "/tmp/thermal_manager.log"
        self.performance_script = "/home/milhy777/performance_manager.sh"
```
