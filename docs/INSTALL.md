# Installation

## Quick Install
```bash
sudo ./scripts/install.sh
```

## Manual
```bash
sudo apt install python3 lm-sensors power-profiles-daemon
sudo modprobe msr
chmod +x scripts/*.sh src/frequency/*.py
```
