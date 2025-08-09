# FORAI Analytics Headers - 2025-07-20T03:17:57.588350
# Agent: claude-code
# Session: unified_20250720_031757_807434
# Context: Systematic FORAI header application - Shell scripts batch
# File: gemini_kiosk_launcher.sh
# Auto-tracking: Enabled
# Memory-integrated: True

#!/bin/bash

# Gemini Kiosk Mode Launcher
# Spustí Gemini v čistém okně bez menu a okrajů

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly GEMINI_URL="https://gemini.google.com/"
readonly APP_MODE_DATA_DIR="$HOME/.local/share/gemini-kiosk"

log() {
    echo "$(date '+%H:%M:%S') [Gemini-Kiosk] $*"
}

# Detect available browsers with kiosk support
detect_browser() {
    if command -v google-chrome >/dev/null 2>&1; then
        echo "chrome"
    elif command -v chromium-browser >/dev/null 2>&1; then
        echo "chromium"
    elif command -v chromium >/dev/null 2>&1; then
        echo "chromium"
    elif command -v firefox >/dev/null 2>&1; then
        echo "firefox"
    else
        echo "none"
    fi
}

# Launch Gemini in Chrome/Chromium kiosk mode
launch_chrome_kiosk() {
    local browser="$1"
    local cmd=""
    
    case "$browser" in
        "chrome")
            cmd="google-chrome"
            ;;
        "chromium")
            cmd="chromium-browser"
            if ! command -v chromium-browser >/dev/null 2>&1; then
                cmd="chromium"
            fi
            ;;
    esac
    
    log "🚀 Launching Gemini in $browser kiosk mode..."
    
    # Create isolated profile directory
    mkdir -p "$APP_MODE_DATA_DIR"
    
    # Launch in kiosk mode with custom parameters
    "$cmd" \
        --app="$GEMINI_URL" \
        --user-data-dir="$APP_MODE_DATA_DIR" \
        --no-first-run \
        --no-default-browser-check \
        --disable-default-apps \
        --disable-extensions \
        --disable-plugins \
        --disable-translate \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-features=TranslateUI \
        --window-size=1400,900 \
        --window-position=100,50 \
        >/dev/null 2>&1 &
    
    log "✅ Gemini kiosk launched successfully"
}

# Launch Gemini in Firefox kiosk mode  
launch_firefox_kiosk() {
    log "🚀 Launching Gemini in Firefox kiosk mode..."
    
    # Create Firefox profile for kiosk mode
    local profile_dir="$APP_MODE_DATA_DIR/firefox-profile"
    mkdir -p "$profile_dir"
    
    # Firefox with minimal UI
    firefox \
        --new-instance \
        --profile "$profile_dir" \
        --kiosk \
        "$GEMINI_URL" \
        >/dev/null 2>&1 &
    
    log "✅ Gemini Firefox kiosk launched"
}

# Alternative: Create desktop app with Electron-like experience
create_desktop_app() {
    local browser="$1"
    
    cat > "/tmp/gemini-kiosk.desktop" << EOF
[Desktop Entry]
Name=Gemini AI (Kiosk)
Comment=Gemini AI in clean window mode
Exec=$SCRIPT_DIR/gemini_kiosk_launcher.sh launch
Icon=applications-development
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
NoDisplay=false
EOF

    log "📱 Desktop app created: /tmp/gemini-kiosk.desktop"
}

# Launch based on detected browser
launch_kiosk() {
    local browser=$(detect_browser)
    
    case "$browser" in
        "chrome"|"chromium")
            launch_chrome_kiosk "$browser"
            ;;
        "firefox")
            launch_firefox_kiosk
            ;;
        "none")
            log "❌ No supported browser found for kiosk mode"
            log "💡 Install Google Chrome, Chromium, or Firefox"
            return 1
            ;;
    esac
}

# Check if Gemini kiosk is already running
check_running() {
    if pgrep -f "gemini.google.com" >/dev/null; then
        log "📱 Gemini kiosk is already running"
        return 0
    else
        log "📱 Gemini kiosk is not running"
        return 1
    fi
}

# Kill running Gemini kiosk instances
kill_kiosk() {
    log "🔄 Stopping Gemini kiosk instances..."
    
    # Kill Chrome/Chromium instances with our data dir
    pkill -f "$APP_MODE_DATA_DIR" 2>/dev/null || true
    
    # Kill Firefox kiosk instances
    pkill -f "firefox.*kiosk.*gemini" 2>/dev/null || true
    
    log "✅ Gemini kiosk stopped"
}

# Install permanent desktop launcher
install_launcher() {
    log "📦 Installing Gemini Kiosk launcher..."
    
    # Create desktop file
    local desktop_file="$HOME/.local/share/applications/gemini-kiosk.desktop"
    cat > "$desktop_file" << EOF
[Desktop Entry]
Name=🤖 Gemini AI (Kiosk)
Comment=Gemini AI in clean fullscreen mode
Exec=$SCRIPT_DIR/gemini_kiosk_launcher.sh launch
Icon=applications-development
Type=Application
Categories=Network;WebBrowser;Development;
StartupNotify=true
Keywords=AI;Gemini;Google;Assistant;
EOF

    log "✅ Launcher installed: $desktop_file"
    log "📱 Find it in: Applications → Development → Gemini AI (Kiosk)"
}

# Update Safe Gemini widget to use kiosk mode
update_widget() {
    log "🔧 Updating Safe Gemini widget to use kiosk mode..."
    
    local widget_file="/home/milhy777/.local/share/plasma/plasmoids/com.powertools.gemini.safe/contents/ui/main.qml"
    
    if [ -f "$widget_file" ]; then
        # Backup original
        cp "$widget_file" "${widget_file}.backup"
        
        # Update with kiosk launcher
        cat > "$widget_file" << 'EOF'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

PlasmoidItem {
    id: root
    
    Layout.minimumWidth: 150
    Layout.minimumHeight: 80
    
    compactRepresentation: PlasmaComponents.Button {
        text: "🤖 Gemini"
        icon.name: "applications-development"
        
        onClicked: {
            // Launch Gemini in kiosk mode (clean window)
            console.log("Launching Gemini kiosk mode...")
            Qt.openUrlExternally("file:///home/milhy777/Develop/PowerManagement/scripts/gemini_kiosk_launcher.sh")
        }
        
        ToolTip.text: "Open Gemini AI in clean kiosk mode"
    }
    
    fullRepresentation: ColumnLayout {
        PlasmaComponents.Label {
            text: "🛡️ Safe Gemini Launcher"
            Layout.alignment: Qt.AlignHCenter
            font.bold: true
        }
        
        PlasmaComponents.Label {
            text: "Clean kiosk mode"
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: 9
            opacity: 0.7
        }
        
        PlasmaComponents.Button {
            text: "🚀 Gemini Kiosk"
            Layout.fillWidth: true
            onClicked: {
                console.log("Launching Gemini kiosk mode...")
                // Direct script execution would be ideal but Qt restrictions...
                // User can create keyboard shortcut or use desktop launcher
            }
        }
        
        PlasmaComponents.Button {
            text: "🌐 Gemini Web"
            Layout.fillWidth: true
            onClicked: Qt.openUrlExternally("https://gemini.google.com/")
        }
        
        PlasmaComponents.Button {
            text: "⚡ AI Performance"
            Layout.fillWidth: true
            onClicked: {
                console.log("AI Performance mode requested");
            }
        }
        
        PlasmaComponents.Label {
            text: "💡 For kiosk mode:\nUse desktop launcher or\nkeyboard shortcut"
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: 8
            opacity: 0.6
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
EOF
        
        log "✅ Widget updated with kiosk mode support"
    else
        log "⚠️ Widget file not found: $widget_file"
    fi
}

# Create keyboard shortcut for quick access
create_shortcut() {
    log "⌨️ Creating keyboard shortcut..."
    
    # KDE shortcut configuration
    local shortcut_file="$HOME/.config/kglobalshortcutsrc"
    
    if [ -f "$shortcut_file" ]; then
        # Add custom shortcut (example: Ctrl+Alt+G)
        log "💡 To create keyboard shortcut:"
        log "   1. System Settings → Shortcuts → Custom Shortcuts"
        log "   2. Add new shortcut: Ctrl+Alt+G"
        log "   3. Command: $SCRIPT_DIR/gemini_kiosk_launcher.sh launch"
    fi
}

# Show browser status and recommendations
show_status() {
    local browser=$(detect_browser)
    
    echo "🤖 Gemini Kiosk Launcher Status"
    echo "==============================="
    echo ""
    
    echo "🌐 Available browsers:"
    case "$browser" in
        "chrome")
            echo "  ✅ Google Chrome (recommended for kiosk mode)"
            ;;
        "chromium")
            echo "  ✅ Chromium (good for kiosk mode)"
            ;;
        "firefox")
            echo "  ⚠️  Firefox (basic kiosk support)"
            ;;
        "none")
            echo "  ❌ No supported browsers found"
            echo "     Install: Google Chrome, Chromium, or Firefox"
            ;;
    esac
    echo ""
    
    echo "📱 Kiosk mode features:"
    echo "  • Clean window without browser UI"
    echo "  • No menu bars, address bars, or tabs"
    echo "  • Isolated profile for security"
    echo "  • Optimized for AI interaction"
    echo ""
    
    if check_running; then
        echo "🟢 Status: Gemini kiosk is currently running"
    else
        echo "🔴 Status: Gemini kiosk is not running"
    fi
}

# Main menu
main() {
    case "${1:-}" in
        "launch")
            launch_kiosk
            ;;
        "kill"|"stop")
            kill_kiosk
            ;;
        "restart")
            kill_kiosk
            sleep 2
            launch_kiosk
            ;;
        "install")
            install_launcher
            update_widget
            create_shortcut
            ;;
        "status")
            show_status
            ;;
        *)
            echo "🤖 Gemini Kiosk Mode Launcher"
            echo "Usage: $0 {launch|kill|restart|install|status}"
            echo ""
            echo "Commands:"
            echo "  launch   - Launch Gemini in clean kiosk mode"
            echo "  kill     - Stop running Gemini kiosk instances"
            echo "  restart  - Restart Gemini kiosk"
            echo "  install  - Install desktop launcher + update widget"
            echo "  status   - Show browser status and recommendations"
            echo ""
            show_status
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi