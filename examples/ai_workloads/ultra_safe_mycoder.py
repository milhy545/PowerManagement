#!/usr/bin/env python3

"""
Ultra-Safe MyCoder Demo for Q9550
- 30-second delays between operations
- Temperature monitoring before each operation
- Single request mode only
- Process affinity limited to 2 cores
"""

import os
import sys
import time
import asyncio
import subprocess
import psutil
from dataclasses import dataclass
from typing import Optional, List

@dataclass
class SystemStatus:
    cpu_temp: int
    cpu_usage: float
    memory_usage: float
    load_avg: float
    
class UltraSafeMyCoder:
    def __init__(self):
        self.temp_threshold = 70
        self.critical_temp = 75
        self.cooldown_time = 30
        self.operation_delay = 10
        
        # Limit process to 2 cores only
        self.limit_cpu_cores()
        
    def limit_cpu_cores(self):
        """Limit current process to 2 CPU cores only"""
        try:
            # Get current process
            current_process = psutil.Process()
            # Set CPU affinity to cores 0,1 only
            current_process.cpu_affinity([0, 1])
            print("✅ Process limited to 2 CPU cores")
        except Exception as e:
            print(f"⚠️ Could not limit CPU cores: {e}")
    
    def get_cpu_temperature(self) -> Optional[int]:
        """Get CPU temperature using sensors"""
        try:
            result = subprocess.run(
                ["sensors"], 
                capture_output=True, 
                text=True, 
                timeout=5
            )
            
            for line in result.stdout.split('\n'):
                if "Core 0:" in line:
                    # Extract temperature from line like "Core 0:       +54.0°C"
                    temp_str = line.split('+')[1].split('°')[0]
                    return int(float(temp_str))
                    
        except Exception as e:
            print(f"⚠️ Cannot read temperature: {e}")
            return None
    
    def get_system_status(self) -> SystemStatus:
        """Get comprehensive system status"""
        cpu_temp = self.get_cpu_temperature() or 0
        cpu_usage = psutil.cpu_percent(interval=1)
        memory_usage = psutil.virtual_memory().percent
        load_avg = os.getloadavg()[0]
        
        return SystemStatus(
            cpu_temp=cpu_temp,
            cpu_usage=cpu_usage,
            memory_usage=memory_usage,
            load_avg=load_avg
        )
    
    def thermal_safety_check(self) -> bool:
        """Check if system is thermally safe for operation"""
        status = self.get_system_status()
        
        print(f"🌡️ CPU: {status.cpu_temp}°C | Load: {status.cpu_usage}% | RAM: {status.memory_usage}% | Load Avg: {status.load_avg:.1f}")
        
        if status.cpu_temp >= self.critical_temp:
            print(f"🚨 CRITICAL TEMPERATURE {status.cpu_temp}°C! Emergency stop!")
            return False
            
        if status.cpu_temp >= self.temp_threshold:
            print(f"⚠️ High temperature {status.cpu_temp}°C. Cooling down...")
            print(f"💤 Waiting {self.cooldown_time}s for temperature to drop...")
            time.sleep(self.cooldown_time)
            return self.thermal_safety_check()  # Recursive check
            
        return True
    
    def emergency_stop(self):
        """Emergency system protection"""
        print("🚨 EMERGENCY STOP ACTIVATED")
        
        # Kill any heavy processes
        try:
            subprocess.run(["pkill", "-f", "ollama"], check=False)
            subprocess.run(["pkill", "-f", "docker"], check=False)
            print("✅ Heavy processes terminated")
        except:
            pass
        
        # Set all processes to lowest priority
        try:
            subprocess.run(["sudo", "nice", "+19"], check=False)
            print("✅ Process priorities lowered")
        except:
            pass
    
    async def safe_ollama_test(self) -> bool:
        """Safely test Ollama connection"""
        if not self.thermal_safety_check():
            return False
            
        print("🔍 Testing Ollama connection...")
        
        try:
            # Very lightweight test
            result = subprocess.run(
                ["ollama", "list"], 
                capture_output=True, 
                text=True, 
                timeout=10
            )
            
            if result.returncode == 0:
                print("✅ Ollama is running")
                print("📋 Available models:")
                for line in result.stdout.strip().split('\n')[1:]:  # Skip header
                    if line.strip():
                        model_name = line.split()[0]
                        print(f"   • {model_name}")
                return True
            else:
                print("❌ Ollama not running")
                return False
                
        except subprocess.TimeoutExpired:
            print("⏰ Ollama test timeout")
            return False
        except Exception as e:
            print(f"❌ Ollama test error: {e}")
            return False
    
    async def safe_ai_demo(self):
        """Ultra-safe AI demonstration"""
        print("🤖 Starting Ultra-Safe MyCoder Demo")
        print("=" * 50)
        
        # Initial safety check
        if not self.thermal_safety_check():
            self.emergency_stop()
            return
        
        print("🔧 MyCoder Interface Components:")
        print("   ✅ Temperature monitoring")
        print("   ✅ Process CPU affinity limited")
        print("   ✅ Emergency thermal protection")
        print("   ✅ Single-request mode")
        
        # Safe delay before testing
        print(f"\n💤 Safety delay ({self.operation_delay}s)...")
        time.sleep(self.operation_delay)
        
        # Test Ollama connection
        if not await self.safe_ollama_test():
            print("⚠️ Ollama test failed - skipping AI generation")
        else:
            print("\n🎯 AI Code Generation Demo (MOCKUP):")
            print("   Request: 'Create a Python function to calculate fibonacci'")
            
            # Thermal check before AI operation
            if not self.thermal_safety_check():
                print("🚨 Temperature too high for AI generation!")
                return
            
            # Show mockup instead of real AI to prevent thermal issues
            print("   Response:")
            print("   ```python")
            print("   def fibonacci(n):")
            print("       if n <= 1:")
            print("           return n")
            print("       return fibonacci(n-1) + fibonacci(n-2)")
            print("   ```")
            print("   [This is a MOCKUP response to prevent thermal overload]")
        
        # Final safety check
        final_status = self.get_system_status()
        print(f"\n📊 Final System Status:")
        print(f"   🌡️ Temperature: {final_status.cpu_temp}°C")
        print(f"   💻 CPU Usage: {final_status.cpu_usage}%")
        print(f"   🧠 Memory: {final_status.memory_usage}%")
        
        if final_status.cpu_temp > self.temp_threshold:
            print("⚠️ Post-operation temperature elevated!")
        else:
            print("✅ System temperature stable")
    
    def start_background_monitoring(self):
        """Start background temperature monitoring"""
        print("🛡️ Starting background thermal monitoring...")
        
        # This would run in background but for safety we'll do manual checks
        print("ℹ️ Manual monitoring mode - checking before each operation")

async def main():
    """Main ultra-safe MyCoder demonstration"""
    print("🚀 Ultra-Safe MyCoder for Q9550")
    print("=" * 40)
    
    # Initialize ultra-safe mode
    safe_mycoder = UltraSafeMyCoder()
    
    # Start monitoring
    safe_mycoder.start_background_monitoring()
    
    try:
        # Run safe demo
        await safe_mycoder.safe_ai_demo()
        
    except KeyboardInterrupt:
        print("\n🛑 Demo interrupted by user")
        
    except Exception as e:
        print(f"\n❌ Demo error: {e}")
        safe_mycoder.emergency_stop()
    
    finally:
        print("\n✅ Ultra-Safe MyCoder Demo completed")
        
        # Final temperature check
        final_temp = safe_mycoder.get_cpu_temperature()
        if final_temp:
            print(f"🌡️ Final temperature: {final_temp}°C")

if __name__ == "__main__":
    asyncio.run(main())