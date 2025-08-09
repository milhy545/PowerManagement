#!/usr/bin/env python3

"""
Streaming MyCoder - "Zkrocená Llama" s thermal pauzami
Streamuje AI response po malých kouscích s thermal monitoring
"""

import time
import json
import subprocess
import requests
import sys

class ThermalStreamingAI:
    def __init__(self):
        self.ollama_url = "http://localhost:11434"
        self.model = "tinyllama:1.1b"
        self.temp_threshold = 65  # Pause threshold
        self.critical_temp = 75   # Emergency stop
        self.chunk_pause = 2      # Seconds between chunks
        self.thermal_pause = 10   # Seconds when hot
        
    def get_cpu_temp(self):
        try:
            result = subprocess.run(["sensors"], capture_output=True, text=True, timeout=2)
            for line in result.stdout.split('\n'):
                if "Core 0:" in line and "+" in line:
                    temp_str = line.split('+')[1].split('°')[0]
                    return int(float(temp_str))
        except:
            return 50
    
    def thermal_check(self, operation=""):
        temp = self.get_cpu_temp()
        print(f"🌡️ {temp}°C", end=" ")
        
        if temp >= self.critical_temp:
            print(f"🚨 CRITICAL! Stopping {operation}")
            return False
        elif temp >= self.temp_threshold:
            print(f"⚠️ HOT! Pause {self.thermal_pause}s")
            time.sleep(self.thermal_pause)
            return self.thermal_check(operation)  # Recursive check
        else:
            print(f"✅ OK")
            return True
    
    def stream_ai_response(self, prompt, max_tokens=50):
        """Stream AI response with thermal pauses"""
        if not self.thermal_check("AI generation"):
            return None
            
        print(f"🤖 Streaming AI response (max {max_tokens} tokens)...")
        print("📝 Response: ", end="", flush=True)
        
        payload = {
            "model": self.model,
            "prompt": prompt,
            "options": {
                "num_predict": max_tokens,
                "temperature": 0.1,
                "top_p": 0.9,
                "num_ctx": 512,  # Small context
            },
            "stream": True  # STREAMING MODE!
        }
        
        try:
            # Start streaming request
            response = requests.post(
                f"{self.ollama_url}/api/generate", 
                json=payload, 
                stream=True,
                timeout=60
            )
            
            if response.status_code != 200:
                print(f"\n❌ Request failed: {response.status_code}")
                return None
                
            full_response = ""
            chunk_count = 0
            
            # Process streaming chunks
            for line in response.iter_lines(decode_unicode=True):
                if line:
                    try:
                        chunk_data = json.loads(line)
                        
                        if 'response' in chunk_data:
                            chunk_text = chunk_data['response']
                            print(chunk_text, end="", flush=True)
                            full_response += chunk_text
                            chunk_count += 1
                            
                            # Thermal pause every 5 chunks
                            if chunk_count % 5 == 0:
                                if not self.thermal_check(f"chunk {chunk_count}"):
                                    print(f"\n🛑 Emergency stop at chunk {chunk_count}")
                                    return full_response
                                
                                # Short pause between chunks
                                time.sleep(self.chunk_pause)
                        
                        # Check if done
                        if chunk_data.get('done', False):
                            break
                            
                    except json.JSONDecodeError:
                        continue
            
            print("\n✅ Streaming completed!")
            return full_response
            
        except requests.exceptions.Timeout:
            print("\n⏰ Streaming timeout")
            return None
        except requests.exceptions.RequestException as e:
            print(f"\n❌ Streaming error: {e}")
            return None
    
    def interactive_streaming(self):
        """Interactive MyCoder s streaming AI"""
        print("🌊 Streaming MyCoder - Zkrocená Llama Edition")
        print("=" * 55)
        print("🦙 Stream po kouscích s thermal pauzami")
        print("🌡️ Auto-pause při 65°C, stop při 75°C")
        print("💡 Příkazy: 'code něco', 'temp', 'quit'")
        print("=" * 55)
        
        session = 0
        
        while True:
            try:
                session += 1
                temp = self.get_cpu_temp()
                
                user_input = input(f"\n🌡️{temp}°C Stream[{session}]> ").strip()
                
                if user_input.lower() in ['quit', 'exit']:
                    print("👋 Streaming MyCoder ukončen!")
                    break
                    
                elif user_input.lower() == 'temp':
                    temp = self.get_cpu_temp()
                    print(f"🌡️ Aktuální teplota: {temp}°C")
                    if temp > self.temp_threshold:
                        print("⚠️ Vysoká teplota - doporučuji pauzu")
                    continue
                    
                elif user_input.startswith('code'):
                    request = user_input[4:].strip() or "hello world function"
                    prompt = f"Write Python code for: {request}\n\nCode:"
                    
                    response = self.stream_ai_response(prompt, max_tokens=80)
                    
                    if response:
                        print(f"\n📊 Generated {len(response)} characters")
                    else:
                        print("❌ Generation failed or stopped")
                        
                elif user_input == '':
                    continue
                    
                else:
                    print(f"🤔 Neznám: '{user_input}'")
                    print("💡 Zkus: 'code <request>', 'temp', 'quit'")
                    
            except (KeyboardInterrupt, EOFError):
                print("\n👋 Streaming session ukončena!")
                break
            except Exception as e:
                print(f"❌ Error: {e}")
                continue
        
        # Final thermal report
        final_temp = self.get_cpu_temp()
        print(f"\n📊 Final temperature: {final_temp}°C")
        print("🦙 Llama úspěšně zkrocena streaming metodou!")

def main():
    print("🌊 Inicializuji Thermal Streaming AI...")
    
    # Quick connectivity test
    try:
        import requests
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        if response.status_code == 200:
            print("✅ Ollama server připojen")
        else:
            print("❌ Ollama server nedostupný")
            sys.exit(1)
    except Exception as e:
        print(f"❌ Connection error: {e}")
        sys.exit(1)
    
    # Start streaming MyCoder
    ai = ThermalStreamingAI()
    ai.interactive_streaming()

if __name__ == "__main__":
    main()