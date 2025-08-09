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
# Use regular pkill - works for our own processes without sudo
pkill -9 -f "performance_manager" 2>/dev/null || true
pkill -9 -f "powerprofilesctl" 2>/dev/null || true
pkill -9 -f "kde_power" 2>/dev/null || true
pkill -9 -f "auto_optimization" 2>/dev/null || true
pkill -9 -f "monitor_system" 2>/dev/null || true
pkill -9 -f "ai_process" 2>/dev/null || true
pkill -9 -f "gpu_thermal" 2>/dev/null || true
pkill -9 -f "mxm_gpu" 2>/dev/null || true
pkill -9 -f "tested_gpu" 2>/dev/null || true

echo "2. Stopping systemd services..."
# Only use sudo if available and not in CI
if [[ "${CI:-false}" != "true" ]] && sudo -n true 2>/dev/null; then
    sudo systemctl stop power-profiles-daemon 2>/dev/null || true
    sudo systemctl restart power-profiles-daemon 2>/dev/null || true
else
    echo "   Skipping systemd operations (no sudo or CI mode)"
fi

echo "3. Cleaning temp files..."
# Safe temp file cleanup - only specific files in /tmp
if [ -f "/tmp/current_power_profile" ]; then
    rm -f /tmp/current_power_profile 2>/dev/null || true
fi
if [ -f "/tmp/power-profiles.conf" ]; then
    rm -f /tmp/power-profiles.conf 2>/dev/null || true
fi

echo "4. Restoring original powerprofilesctl..."
# Only restore if files exist and we have sudo
if [[ "${CI:-false}" != "true" ]] && sudo -n true 2>/dev/null; then
    if [ -f /usr/bin/powerprofilesctl.original ]; then
        sudo cp /usr/bin/powerprofilesctl.original /usr/bin/powerprofilesctl 2>/dev/null || true
    fi
    
    if [ -f /usr/libexec/power-profiles-daemon.original ]; then
        sudo cp /usr/libexec/power-profiles-daemon.original /usr/libexec/power-profiles-daemon 2>/dev/null || true
    fi
else
    echo "   Skipping restore operations (no sudo or CI mode)"
fi

echo "5. Current process count:"
ps aux | grep -E "(performance|power|kde_|auto_)" | grep -v grep | wc -l

echo "✅ CLEANUP COMPLETE!"