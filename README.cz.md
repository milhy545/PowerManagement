# 🚀 Linux Power Management Suite

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hardware: Universal](https://img.shields.io/badge/Hardware-Universal%20%2F%20LGA775-blue.svg)](https://github.com/milhy545/PowerManagement)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-orange.svg)](https://www.kernel.org/)  
[🇬🇧 English version available here](./README.md)

Profesionální nástroj pro správu napájení v Linuxu s **univerzální kompatibilitou CPU/GPU**, **pokročilým monitoringem senzorů** a **inteligentním řízením ventilátorů (PWM)**. Vyvinuto a otestováno na atypických a chlazením limitovaných sestavách (včetně All-in-One PC).

---

## 🎯 Proč tento projekt vznikl (The Backstory)

V roce 2024 jsem osadil starší All-in-One počítač z roku 2010 (Acer) podstatně výkonnějším 95W procesorem **Core 2 Quad Q9550** (vrchol patice LGA775) namísto původního pomalého dvoujádra.

Kompaktní plastové šasi All-in-One počítače však nebylo na takové odpadní teplo stavěné:
- I s otevřeným zadním krytem a velkým stolním ventilátorem foukajícím přímo na desku dosahoval procesor při zátěži všech 4 jader teploty **82 °C během 20 minut** a systém se nouzově vypínal.
- Standardní linuxové regulátory (CPU governors) nedokázaly reagovat dostatečně rychle a jemně.

**Inženýrské řešení:**  
Napsal jsem vlastní systémovou suitu v Linuxu, která přistupuje přímo k **MSR registrům (Model-Specific Registers)** procesoru. Skript dynamicky krokuje násobiče a frekvence, řídí křivky PWM ventilátorů a multiplexuje zátěž jader tak, aby procesor nikdy neběžel na 100 % na všech jádrech naráz. Tím se systém bezpečně udržel pod kritickou teplotou.

Později se procesor Q9550 přestěhoval do lépe chlazeného Dell OptiPlexu, ale tato suita zůstala jako univerzální, prověřený nástroj pro ladění spotřeby a teplot starého křemíku.

---

## ✨ Klíčové funkce

- **MSR Frequency Throttling:** Nízkoúrovňové řízení P-states a frekvencí přímo přes procesorové registry.
- **Inteligentní PWM řízení ventilátorů:** Dynamické mapování otáček dle reálných teplot senzorů.
- **Univerzální monitoring senzorů:** Čtení teplot jader, GPU (NVIDIA/AMD/Intel) i atypických čidel základních desek.
- **Logging a varování:** Běh jako systémový démon s exportem telemetrie do JSON logů.
