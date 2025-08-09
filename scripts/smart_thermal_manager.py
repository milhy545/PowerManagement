#!/usr/bin/env python3

"""
Smart Thermal Manager - Upgraded Performance Manager
Kombinuje funkční části starého systému + nové thermal features
"""

import os
import sys
import time
import subprocess
import threading
import psutil
from dataclasses import dataclass
from typing import Optional, List
from enum import Enum

class PowerMode(Enum):
    PERFORMANCE = "performance"
    BALANCED = "balanced" 
    POWER_SAVE = "power-saver"
    EMERGENCY = "emergency"

@dataclass
class SystemStatus:
    cpu_temp: int
    cpu_usage: float
    load_avg: float
    power_mode: PowerMode
    
class SmartThermalManager:
    def __init__(self):
        # Thermal thresholds (based on working old system)
        self.comfort_temp = 65    # Below this = performance OK
        self.warning_temp = 70    # Your old system worked here
        self.critical_temp = 80   # Where old system dropped load
        self.emergency_temp = 83  # Shutdown threshold
        
        # State tracking
        self.current_mode = PowerMode.BALANCED
        self.monitoring = False
        self.escalation_count = 0
        
        # Process tracking for AI workloads
        self.ai_processes = []
        
    def log(self, message):
        timestamp = time.strftime("%H:%M:%S")
        print(f"{timestamp} - {message}")
        
    def get_cpu_temperature(self) -> int:
        """Get CPU temperature using multiple methods"""
        # Method 1: sensors command (most reliable)
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
            
        return 0
    
    def get_system_status(self) -> SystemStatus:
        """Get comprehensive system status"""
        return SystemStatus(
            cpu_temp=self.get_cpu_temperature(),
            cpu_usage=psutil.cpu_percent(interval=0.5),
            load_avg=os.getloadavg()[0],
            power_mode=self.current_mode
        )
    
    def set_power_profile(self, mode: PowerMode) -> bool:
        """Set system power profile using powerprofilesctl"""
        try:
            cmd = ["sudo", "powerprofilesctl", "set", mode.value]
            result = subprocess.run(cmd, capture_output=True, timeout=10)
            
            if result.returncode == 0:
                self.current_mode = mode
                self.log(f"✅ Power mode: {mode.value}")
                return True
            else:
                self.log(f"❌ Power mode failed: {mode.value}")
                return False
        except Exception as e:
            self.log(f"❌ Power mode error: {e}")
            return False
    
    def find_ai_processes(self) -> List[int]:
        """Find AI-related processes"""
        ai_patterns = ["ollama", "claude", "python.*ai", "python.*mycoder", "gemini"]
        pids = []
        
        try:
            for pattern in ai_patterns:
                result = subprocess.run(
                    ["pgrep", "-f", pattern], 
                    capture_output=True, text=True
                )
                if result.returncode == 0:
                    for pid in result.stdout.strip().split('\n'):
                        if pid.strip():
                            pids.append(int(pid.strip()))
        except:
            pass
            
        return pids
    
    def throttle_ai_processes(self, nice_level: int = 10):
        """Throttle AI processes to reduce CPU load"""
        ai_pids = self.find_ai_processes()
        throttled = 0
        
        for pid in ai_pids:
            try:
                # Set process priority
                subprocess.run(["sudo", "renice", f"+{nice_level}", str(pid)], 
                             check=False, timeout=2)
                
                # Limit to specific CPU cores (core rotation)
                if nice_level > 15:  # Emergency mode
                    # Limit to single core
                    subprocess.run(["sudo", "taskset", "-cp", "0", str(pid)], 
                                 check=False, timeout=2)
                elif nice_level > 5:  # Warning mode  
                    # Limit to 2 cores
                    subprocess.run(["sudo", "taskset", "-cp", "0,1", str(pid)], 
                                 check=False, timeout=2)
                
                throttled += 1
            except:
                continue
                
        if throttled > 0:
            self.log(f"🎛️ Throttled {throttled} AI processes (nice +{nice_level})")
            
        return throttled
    
    def emergency_kill_heavy_processes(self):
        """Emergency process termination (from old temperature_guardian)"""
        self.log("🚨 EMERGENCY: Killing heavy processes")
        
        heavy_patterns = ["docker", "ollama", "python.*ollama", "npm", "python.*mycoder"]
        
        for pattern in heavy_patterns:
            try:
                subprocess.run(["pkill", "-f", pattern], check=False, timeout=3)
            except:
                continue
                
        # Clear memory (from old system)
        try:
            subprocess.run(["sudo", "sync"], check=False, timeout=5)
            subprocess.run(["sudo", "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"], 
                         check=False, timeout=5)
        except:
            pass
            
        self.log("🛑 Emergency cleanup completed")
    
    def adaptive_thermal_response(self, temp: int, cpu_usage: float):
        """
        Adaptive thermal response based on old working system:
        - Below 65°C: Performance OK
        - 65-70°C: Start throttling AI
        - 70-80°C: Progressive escalation (your old system's sweet spot)
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
            # Warning zone - your old system worked here with gradual reduction
            self.escalation_count += 1
            
            if self.escalation_count <= 3:
                # Progressive throttling (like old system)
                self.set_power_profile(PowerMode.POWER_SAVE)
                self.throttle_ai_processes(nice_level=10 + (self.escalation_count * 2))
                self.log(f"⚠️ {temp}°C - Progressive throttling level {self.escalation_count}")
            else:
                # Escalate to emergency
                self.set_power_profile(PowerMode.EMERGENCY)
                self.throttle_ai_processes(nice_level=19)
                
        elif temp >= self.emergency_temp:
            # Critical - immediate emergency stop
            self.log(f"🚨 CRITICAL {temp}°C - Emergency shutdown!")
            self.set_power_profile(PowerMode.EMERGENCY)
            self.emergency_kill_heavy_processes()
            self.escalation_count = 10  # Max escalation
            
        else:  # 80-83°C range
            # High risk zone - aggressive throttling but don't panic yet
            self.set_power_profile(PowerMode.EMERGENCY)
            self.throttle_ai_processes(nice_level=19)
            self.log(f"🔥 {temp}°C - High risk thermal zone")
    
    def thermal_monitoring_loop(self):
        """Continuous thermal monitoring (like old temperature_guardian)"""
        self.log("🛡️ Starting adaptive thermal monitoring...")
        self.monitoring = True
        
        while self.monitoring:
            try:
                status = self.get_system_status()
                
                # Display status every 10 cycles (20 seconds)
                if int(time.time()) % 20 == 0:
                    self.log(f"📊 {status.cpu_temp}°C | CPU: {status.cpu_usage:.1f}% | Load: {status.load_avg:.1f} | Mode: {status.power_mode.value}")
                
                # Apply adaptive thermal response
                self.adaptive_thermal_response(status.cpu_temp, status.cpu_usage)
                
                # Monitor every 2 seconds (like old guardian)
                time.sleep(2)
                
            except KeyboardInterrupt:
                self.log("🛑 Monitoring stopped by user")
                break
            except Exception as e:
                self.log(f"❌ Monitoring error: {e}")
                time.sleep(5)  # Longer delay on error
                
        self.monitoring = False
    
    def start_monitoring(self):
        """Start thermal monitoring in background thread"""
        if self.monitoring:
            self.log("⚠️ Monitoring already running")
            return
            
        monitor_thread = threading.Thread(target=self.thermal_monitoring_loop)
        monitor_thread.daemon = True
        monitor_thread.start()
        
        self.log("🚀 Smart Thermal Manager started")
        return monitor_thread
    
    def stop_monitoring(self):
        """Stop thermal monitoring"""
        self.monitoring = False
        self.log("🛑 Thermal monitoring stopped")
    
    def status_report(self):
        """Generate status report"""
        status = self.get_system_status()
        ai_count = len(self.find_ai_processes())
        
        print("🔍 Smart Thermal Manager Status")
        print("=" * 35)
        print(f"🌡️ CPU Temperature: {status.cpu_temp}°C")
        print(f"💻 CPU Usage: {status.cpu_usage:.1f}%")
        print(f"📈 Load Average: {status.load_avg:.1f}")
        print(f"⚡ Power Mode: {status.power_mode.value}")
        print(f"🤖 AI Processes: {ai_count}")
        print(f"📊 Escalation Level: {self.escalation_count}/10")
        print(f"🛡️ Monitoring: {'Active' if self.monitoring else 'Stopped'}")

def main():
    if len(sys.argv) < 2:
        print("Usage: smart_thermal_manager.py {start|stop|status|test}")
        sys.exit(1)
        
    manager = SmartThermalManager()
    command = sys.argv[1].lower()
    
    if command == "start":
        thread = manager.start_monitoring()
        try:
            # Keep main thread alive
            while manager.monitoring:
                time.sleep(1)
        except KeyboardInterrupt:
            manager.stop_monitoring()
            
    elif command == "stop":
        manager.stop_monitoring()
        
    elif command == "status":
        manager.status_report()
        
    elif command == "test":
        manager.log("🧪 Running thermal test...")
        status = manager.get_system_status()
        manager.adaptive_thermal_response(status.cpu_temp, status.cpu_usage)
        manager.status_report()
        
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()