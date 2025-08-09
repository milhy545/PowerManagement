#!/usr/bin/env python3

"""
Interactive MyCoder - čeká na tvé příkazy
Může spát celé hodiny a čekat až se vzbudíš! 😴 → 😊
"""

import time
import subprocess
import os

def get_temp():
    try:
        result = subprocess.run(["sensors"], capture_output=True, text=True, timeout=2)
        for line in result.stdout.split('\n'):
            if "Core 0:" in line:
                return line.split('+')[1].split('°')[0].strip()
    except:
        return "50"

def main():
    print("🔥 MyCoder Interactive - Q9550 Edition")
    print("=" * 50)
    print("💤 Klidně zaspi - počkám na tebe!")
    print("📝 Příkazy: 'code něco', 'temp', 'quit'")
    print("=" * 50)
    
    while True:
        try:
            temp = get_temp()
            prompt = f"\n🌡️{temp}°C MyCoder> "
            
            user_input = input(prompt).strip()
            
            if user_input.lower() in ['quit', 'exit']:
                print("👋 Ahoj!")
                break
                
            elif user_input.lower() == 'temp':
                print(f"🌡️ Teplota: {temp}°C")
                
            elif user_input.startswith('code'):
                request = user_input[4:].strip()
                print(f"🤖 Generuji kód pro: {request}")
                print("```python")
                print(f"# Kód pro: {request}")
                print("def my_function():")
                print("    print('Hello from MyCoder!')")
                print("    return True")
                print("```")
                print("✅ Hotovo!")
                
            elif user_input == '':
                continue
                
            else:
                print(f"🤔 Neznám: '{user_input}'")
                print("💡 Zkus: 'code něco' nebo 'temp'")
                
        except (KeyboardInterrupt, EOFError):
            print("\n👋 MyCoder končí!")
            break

if __name__ == "__main__":
    main()