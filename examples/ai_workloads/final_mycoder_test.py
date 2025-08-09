#!/usr/bin/env python3

"""
Final MyCoder Test - With Smart Thermal Management
"""

import time
import subprocess
import sys
import os

def get_temp():
    try:
        result = subprocess.run(["sensors"], capture_output=True, text=True, timeout=3)
        for line in result.stdout.split('\n'):
            if "Core 0:" in line and "+" in line:
                temp_str = line.split('+')[1].split('°')[0]
                return int(float(temp_str))
    except:
        pass
    return 0

def thermal_check(operation_name):
    temp = get_temp()
    print(f"🌡️ {operation_name}: {temp}°C", end="")
    
    if temp > 75:
        print(" 🚨 TOO HOT! Aborting")
        return False
    elif temp > 70:
        print(" ⚠️ Warning - cooling 10s")
        time.sleep(10)
        return thermal_check(operation_name)
    else:
        print(" ✅ Safe")
        return True

def simple_ai_request():
    if not thermal_check("Pre-AI"):
        return None
        
    print("🤖 Requesting simple AI generation...")
    
    # Ultra-simple request with timeout
    payload = {
        "model": "tinyllama:1.1b",
        "prompt": "def hello():",
        "options": {"num_predict": 30}
    }
    
    import json
    cmd = [
        "curl", "-s", "-X", "POST", 
        "http://localhost:11434/api/generate",
        "-H", "Content-Type: application/json",
        "-d", json.dumps(payload),
        "--max-time", "45"
    ]
    
    try:
        start_temp = get_temp()
        start_time = time.time()
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        
        end_time = time.time()
        end_temp = get_temp()
        
        duration = end_time - start_time
        temp_rise = end_temp - start_temp
        
        print(f"⏱️ Duration: {duration:.1f}s | Temperature: {start_temp}°C → {end_temp}°C ({temp_rise:+d}°C)")
        
        if result.returncode == 0:
            try:
                response_data = json.loads(result.stdout)
                response = response_data.get('response', '').strip()
                if response:
                    print("🤖 AI Response:")
                    print(f"   {response}")
                    return response
                else:
                    print("❌ Empty response")
            except json.JSONDecodeError:
                print("❌ JSON decode error")
        else:
            print(f"❌ Request failed: {result.returncode}")
            
    except subprocess.TimeoutExpired:
        print("⏰ AI request timeout (60s)")
    except Exception as e:
        print(f"❌ AI request error: {e}")
    
    thermal_check("Post-AI")
    return None

def main():
    print("🔥 Final MyCoder Test - Smart Thermal Protection")
    print("=" * 50)
    
    # Initial status
    if not thermal_check("Initial"):
        print("🚨 System too hot to start!")
        return
        
    # Test Ollama connectivity
    try:
        result = subprocess.run(
            ["curl", "-s", "http://localhost:11434/api/tags"],
            capture_output=True, timeout=5
        )
        if result.returncode != 0:
            print("❌ Ollama not running")
            return
        print("✅ Ollama connected")
    except:
        print("❌ Ollama connection failed")
        return
    
    # Simple AI generation test
    print("\n📝 Testing AI Code Generation...")
    response = simple_ai_request()
    
    if response:
        print("\n🎉 SUCCESS! MyCoder AI generation works with thermal protection!")
    else:
        print("\n⚠️ AI generation failed or was thermally protected")
    
    # Final thermal check
    final_temp = get_temp()
    print(f"\n📊 Final temperature: {final_temp}°C")
    
    if final_temp < 60:
        print("✅ System remained cool - safe for continued use")
    elif final_temp < 70:
        print("⚖️ System warm but stable - monitor for longer sessions")
    else:
        print("🔥 System hot - needs cooling before next session")

if __name__ == "__main__":
    main()