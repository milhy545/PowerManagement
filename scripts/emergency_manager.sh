#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
case "${1:-}" in
    cleanup) pkill -f "performance_manager|powerprofilesctl" || true; sync;;
    throttle) python3 "$SCRIPT_DIR/../src/frequency/cpu_frequency_manager.py" thermal emergency;;
    protect) "$SCRIPT_DIR/performance_manager.sh" emergency;;
    recover) "$0" cleanup; "$0" throttle; "$0" protect;;
    *) echo "Usage: emergency_manager.sh {cleanup|throttle|protect|recover}";;
esac
