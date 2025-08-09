#!/usr/bin/env python3

"""
MyCoder Demo - Předpřipravené AI generování příklady
"""

import os
import sys
import time
import json
import asyncio
import aiohttp
import subprocess
import psutil

class MyCoderDemo:
    def __init__(self):
        self.ollama_url = "http://localhost:11434"
        self.model_name = "tinyllama:1.1b"
        self.temp_threshold = 65
        self.critical_temp = 70
        
        # Limit to 2 cores
        try:
            current_process = psutil.Process()
            current_process.cpu_affinity([0, 1])
            current_process.nice(19)
            print("✅ Process limited: 2 cores, lowest priority")
        except Exception as e:
            print(f"⚠️ Process limiting failed: {e}")
    
    def get_cpu_temperature(self):
        try:
            result = subprocess.run(["sensors"], capture_output=True, text=True, timeout=3)
            for line in result.stdout.split('\n'):
                if "Core 0:" in line:
                    temp_str = line.split('+')[1].split('°')[0]
                    return int(float(temp_str))
        except:
            return None
    
    def thermal_check(self):
        temp = self.get_cpu_temperature()
        if not temp:
            return False
            
        cpu_usage = psutil.cpu_percent(interval=0.5)
        print(f"🌡️ {temp}°C | CPU: {cpu_usage}%", end="")
        
        if temp >= self.critical_temp:
            print(f" 🚨 CRITICAL!")
            return False
        elif temp >= self.temp_threshold:
            print(f" ⚠️ HOT! Waiting...")
            time.sleep(15)
            return self.thermal_check()
        else:
            print(" ✅ Safe")
            return True
    
    async def ai_generate(self, prompt, max_tokens=200):
        if not self.thermal_check():
            return None
            
        print(f"🤖 AI generating...")
        
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
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30)) as session:
                start_temp = self.get_cpu_temperature()
                
                async with session.post(f"{self.ollama_url}/api/generate", json=payload) as response:
                    if response.status == 200:
                        result = await response.json()
                        
                        end_temp = self.get_cpu_temperature()
                        if end_temp and start_temp:
                            temp_rise = end_temp - start_temp
                            print(f"🌡️ Temperature change: {temp_rise:+d}°C")
                            if temp_rise > 3:
                                time.sleep(10)
                        
                        return result.get('response', '').strip()
                    else:
                        print(f"❌ Request failed: {response.status}")
                        return None
        except Exception as e:
            print(f"❌ Generation failed: {e}")
            return None
    
    async def run_demos(self):
        print("🔥 MyCoder AI Demo - Předpřipravené příklady")
        print("=" * 50)
        
        demos = [
            {
                "title": "Fibonacci Function",
                "prompt": "Write a Python function to calculate fibonacci numbers recursively. Include brief explanation:"
            },
            {
                "title": "List Sorting", 
                "prompt": "Write a Python function to sort a list using bubble sort algorithm. Add comments:"
            },
            {
                "title": "File Reader",
                "prompt": "Write a Python function to read a text file safely with error handling:"
            }
        ]
        
        for i, demo in enumerate(demos, 1):
            print(f"\n📝 Demo {i}: {demo['title']}")
            print("-" * 30)
            
            response = await self.ai_generate(demo['prompt'])
            
            if response:
                print("🤖 MyCoder AI Response:")
                print(response)
            else:
                print("❌ Generation failed or thermal protection activated")
            
            print(f"\n💤 Cooldown před dalším demo...")
            await asyncio.sleep(15)  # Cooldown mezi demos
        
        final_temp = self.get_cpu_temperature()
        print(f"\n✅ All demos completed! Final temp: {final_temp}°C")

async def main():
    print("🚀 MyCoder Demo Starting...")
    
    # Check Ollama
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get("http://localhost:11434/api/tags") as response:
                if response.status != 200:
                    print("❌ Ollama not accessible")
                    return
    except:
        print("❌ Ollama not running")
        return
    
    demo = MyCoderDemo()
    await demo.run_demos()

if __name__ == "__main__":
    asyncio.run(main())