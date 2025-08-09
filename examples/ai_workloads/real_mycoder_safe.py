#!/usr/bin/env python3

"""
Real MyCoder with AI Generation - Ultra Safe Edition
- Skutečné AI generování s TinyLlama
- Thermal monitoring mezi každým requestem
- Automatic process limiting
"""

import os
import sys
import time
import json
import asyncio
import aiohttp
import subprocess
import psutil
from dataclasses import dataclass
from typing import Optional, Dict, Any

class ThermalMyCoder:
    def __init__(self):
        self.ollama_url = "http://localhost:11434"
        self.model_name = "tinyllama:1.1b"  # Nejlehčí model
        self.temp_threshold = 65  # Snížený threshold pro real AI
        self.critical_temp = 70   # Ještě víc konzervativní
        
        # Limit process to 2 cores
        self.limit_cpu_cores()
        
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
    
    def get_cpu_temperature(self) -> Optional[int]:
        """Získej teplotu CPU"""
        try:
            result = subprocess.run(
                ["sensors"], 
                capture_output=True, 
                text=True, 
                timeout=3
            )
            
            for line in result.stdout.split('\n'):
                if "Core 0:" in line:
                    temp_str = line.split('+')[1].split('°')[0]
                    return int(float(temp_str))
                    
        except Exception:
            return None
    
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
            time.sleep(15)  # Delší cooldown pro real AI
            return self.thermal_safety_check()
            
        print(" ✅ Safe")
        return True
    
    def emergency_thermal_stop(self):
        """Emergency stop"""
        print("\n🚨 EMERGENCY THERMAL STOP!")
        try:
            # Kill heavy processes
            subprocess.run(["pkill", "-f", "ollama"], check=False)
            subprocess.run(["pkill", "-f", "python.*ollama"], check=False)
            
            # Lower all process priorities
            for proc in psutil.process_iter(['pid']):
                try:
                    proc.nice(19)
                except:
                    pass
                    
            print("✅ Emergency procedures completed")
        except Exception as e:
            print(f"❌ Emergency stop failed: {e}")
    
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
                "temperature": 0.3,  # Nižší temperatura = rychlejší
                "top_p": 0.9,
                "num_ctx": 1024,     # Menší context = rychlejší
            },
            "stream": False
        }
        
        try:
            async with aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=30)
            ) as session:
                
                # Monitor temperature during request
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
                            
                            if temp_rise > 5:  # Pokud vzrostla o více než 5°C
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
    
    async def interactive_mycoder(self):
        """Interaktivní MyCoder session"""
        print("🚀 Real MyCoder - Interactive AI Coding Assistant")
        print("=" * 55)
        print("🌡️ Thermal-protected real AI generation active")
        print("💡 Type 'quit' to exit, 'temp' for temperature")
        print("=" * 55)
        
        session_count = 0
        
        while True:
            try:
                # Pre-prompt thermal check
                if not self.thermal_safety_check():
                    print("🚨 System too hot! Exiting for safety.")
                    break
                
                # Get user input
                print(f"\n[Session {session_count + 1}]")
                user_input = input("🔥 MyCoder> ").strip()
                
                if user_input.lower() == 'quit':
                    print("👋 Goodbye!")
                    break
                    
                if user_input.lower() == 'temp':
                    temp = self.get_cpu_temperature()
                    print(f"🌡️ Current temperature: {temp}°C")
                    continue
                
                if not user_input:
                    continue
                
                # Create coding-focused prompt
                coding_prompt = f"Write a Python function or code snippet for: {user_input}\n\nProvide clean, working code with brief explanation:"
                
                # Generate AI response
                response = await self.ai_generate(coding_prompt, max_tokens=200)
                
                if response:
                    print("\n🤖 MyCoder AI Response:")
                    print("-" * 40)
                    print(response)
                    print("-" * 40)
                else:
                    print("❌ AI generation failed or thermal protection activated")
                
                session_count += 1
                
                # Inter-session cooldown
                if session_count % 3 == 0:  # Každé 3 requesty
                    print("💤 Session cooldown (10s)...")
                    time.sleep(10)
                
            except KeyboardInterrupt:
                print("\n🛑 Session interrupted")
                break
            except Exception as e:
                print(f"❌ Session error: {e}")
                self.emergency_thermal_stop()
                break
        
        # Final status
        final_temp = self.get_cpu_temperature()
        print(f"\n📊 Session completed. Final temperature: {final_temp}°C")

async def main():
    """Main MyCoder launcher"""
    print("🔥 Real MyCoder with AI Generation")
    print("⚠️  Ultra-Safe Thermal Protection Active")
    
    # Check if Ollama is running
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get("http://localhost:11434/api/tags") as response:
                if response.status != 200:
                    print("❌ Ollama server not accessible")
                    return
    except:
        print("❌ Ollama server not running. Please start with 'ollama serve'")
        return
    
    # Initialize and run MyCoder
    mycoder = ThermalMyCoder()
    await mycoder.interactive_mycoder()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as e:
        print(f"💥 MyCoder crashed: {e}")
        # Emergency cleanup
        subprocess.run(["pkill", "-f", "python.*mycoder"], check=False)