# FORAI Analytics Headers - 2025-07-20T03:17:57.583455
# Agent: claude-code
# Session: unified_20250720_031757_807434
# Context: Systematic FORAI header application - Shell scripts batch
# File: EMERGENCY_CLEANUP.sh
# Auto-tracking: Enabled
# Memory-integrated: True

#!/bin/bash

# EMERGENCY CLEANUP - Zastavit všechny moje procesy
echo "🚨 EMERGENCY CLEANUP"
echo "==================="

echo "1. Killing all my scripts..."
sudo pkill -9 -f "performance_manager"
sudo pkill -9 -f "powerprofilesctl" 
sudo pkill -9 -f "kde_power"
sudo pkill -9 -f "auto_optimization"
sudo pkill -9 -f "monitor_system"
sudo pkill -9 -f "ai_process"
sudo pkill -9 -f "gpu_thermal"
sudo pkill -9 -f "mxm_gpu"
sudo pkill -9 -f "tested_gpu"

echo "2. Stopping systemd services..."
sudo systemctl stop power-profiles-daemon
sudo systemctl restart power-profiles-daemon

echo "3. Cleaning temp files..."
sudo rm -f /tmp/current_power_profile
sudo rm -f /tmp/power-profiles.conf

echo "4. Restoring original powerprofilesctl..."
if [ -f /usr/bin/powerprofilesctl.original ]; then
    sudo cp /usr/bin/powerprofilesctl.original /usr/bin/powerprofilesctl
fi

if [ -f /usr/libexec/power-profiles-daemon.original ]; then
    sudo cp /usr/libexec/power-profiles-daemon.original /usr/libexec/power-profiles-daemon
fi

echo "5. Current process count:"
ps aux | grep -E "(performance|power|kde_|auto_)" | grep -v grep | wc -l

echo "✅ CLEANUP COMPLETE!"