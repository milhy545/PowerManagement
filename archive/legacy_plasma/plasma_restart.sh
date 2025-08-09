# FORAI Analytics Headers - 2025-07-20T03:17:57.585611
# Agent: claude-code
# Session: unified_20250720_031757_807434
# Context: Systematic FORAI header application - Shell scripts batch
# File: plasma_restart.sh
# Auto-tracking: Enabled
# Memory-integrated: True

#!/bin/bash

# Safe Plasma 6 Restart Script
# Fixes locale issues and safely restarts Plasma

set -euo pipefail

# Fix locale for Plasma 6
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

log() {
    echo "$(date '+%H:%M:%S') [Plasma] $*"
}

# Check Plasma version
check_plasma_version() {
    local version
    version=$(plasmashell --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    echo "$version"
}

# Safe Plasma restart for version 6
restart_plasma6() {
    log "🔄 Restarting Plasma 6.x..."
    
    # Kill existing plasmashell gently
    if pgrep plasmashell >/dev/null; then
        log "📱 Stopping current plasmashell..."
        pkill plasmashell || true
        sleep 2
    fi
    
    # Update widget cache
    log "🔄 Updating widget cache..."
    kbuildsycoca6 2>/dev/null || true
    
    # Start plasmashell with proper environment
    log "🚀 Starting plasmashell..."
    LC_ALL=C.UTF-8 LANG=C.UTF-8 plasmashell >/dev/null 2>&1 &
    
    sleep 3
    
    if pgrep plasmashell >/dev/null; then
        log "✅ Plasma restarted successfully!"
    else
        log "❌ Failed to start plasmashell"
        return 1
    fi
}

# Safe Plasma restart for version 5
restart_plasma5() {
    log "🔄 Restarting Plasma 5.x..."
    
    kquitapp5 plasmashell 2>/dev/null || pkill plasmashell || true
    sleep 2
    kstart5 plasmashell >/dev/null 2>&1 &
    
    sleep 3
    log "✅ Plasma 5 restarted!"
}

# Main restart function
restart_plasma() {
    local version
    version=$(check_plasma_version)
    
    log "📋 Detected Plasma version: $version"
    
    if [[ "$version" =~ ^6\. ]]; then
        restart_plasma6
    elif [[ "$version" =~ ^5\. ]]; then
        restart_plasma5
    else
        log "❌ Unknown Plasma version: $version"
        log "💡 Trying generic restart..."
        pkill plasmashell || true
        sleep 2
        LC_ALL=C.UTF-8 LANG=C.UTF-8 plasmashell >/dev/null 2>&1 &
    fi
}

# Quick widget refresh without restart
refresh_widgets() {
    log "🔄 Refreshing widgets only..."
    kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null || true
    log "✅ Widget cache refreshed"
}

# Check if Plasma is running
check_plasma_status() {
    if pgrep plasmashell >/dev/null; then
        log "✅ Plasmashell is running (PID: $(pgrep plasmashell))"
        log "📋 Version: $(check_plasma_version)"
    else
        log "❌ Plasmashell is NOT running"
    fi
}

# Main menu
main() {
    case "${1:-}" in
        "restart")
            restart_plasma
            ;;
        "refresh")
            refresh_widgets
            ;;
        "status")
            check_plasma_status
            ;;
        "start")
            log "🚀 Starting plasmashell..."
            LC_ALL=C.UTF-8 LANG=C.UTF-8 plasmashell >/dev/null 2>&1 &
            sleep 2
            check_plasma_status
            ;;
        *)
            echo "🖥️ Plasma 6 Safe Restart Tool"
            echo "Usage: $0 {restart|refresh|status|start}"
            echo ""
            echo "Commands:"
            echo "  restart  - Safely restart Plasma (full restart)"
            echo "  refresh  - Refresh widgets only (no restart)"
            echo "  status   - Check if Plasma is running"
            echo "  start    - Start Plasma if not running"
            echo ""
            check_plasma_status
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi