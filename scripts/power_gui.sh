#!/bin/bash

# Power Management GUI - KDE/Zenity interface
# Version: 1.0

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly PERFORMANCE_SCRIPT="$SCRIPT_DIR/performance_manager.sh"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly AI_SCRIPT="$SCRIPT_DIR/ai_process_manager.sh"
readonly CONFIG_DIR="$HOME/.config/power-management-gui"
readonly CONFIG_FILE="$CONFIG_DIR/settings.conf"

# Load/save window settings
load_window_settings() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Defaults
        WINDOW_WIDTH=1000
        WINDOW_HEIGHT=450
        GUI_FRAMEWORK=""
    fi
}

save_window_settings() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
# Power Management GUI Settings
WINDOW_WIDTH=$WINDOW_WIDTH
WINDOW_HEIGHT=$WINDOW_HEIGHT
GUI_FRAMEWORK=$(detect_gui)
EOF
}

# Detect GUI framework
detect_gui() {
    if command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"
    elif command -v zenity >/dev/null 2>&1; then
        echo "zenity"
    else
        echo "none"
    fi
}

# Show error message
show_error() {
    local message="$1"
    local gui="$(detect_gui)"
    
    case "$gui" in
        "kdialog")
            kdialog --error "$message"
            ;;
        "zenity")
            zenity --error --text="$message"
            ;;
        *)
            echo "ERROR: $message" >&2
            ;;
    esac
}

# Show info message
show_info() {
    local message="$1"
    local gui="$(detect_gui)"
    
    case "$gui" in
        "kdialog")
            kdialog --msgbox "$message"
            ;;
        "zenity")
            zenity --info --text="$message"
            ;;
        *)
            echo "INFO: $message"
            ;;
    esac
}

# Power management menu
power_menu() {
    local gui="$(detect_gui)"
    local choice
    
    case "$gui" in
        "kdialog")
            choice=$(kdialog --menu "🚀 Power Management Suite" \
                "performance" "🔥 Performance - Max CPU + GPU" \
                "balanced" "⚖️ Balanced - Smart management" \
                "powersave" "🔋 Power Save - Low power" \
                "emergency" "🚨 Emergency - Recovery" \
                "status" "📊 Show System Status" \
                "ai-menu" "🤖 AI Process Manager Menu")
            ;;
        "zenity")
            choice=$(zenity --list --title="🚀 Power Management Suite" \
                --column="Mode" --column="Description" \
                "performance" "🔥 Performance - Max CPU + GPU" \
                "balanced" "⚖️ Balanced - Smart management" \
                "powersave" "🔋 Power Save - Low power" \
                "emergency" "🚨 Emergency - Recovery" \
                "status" "📊 Show System Status" \
                "ai-menu" "🤖 AI Process Manager Menu" \
                --width=1000 --height=450)
            ;;
        *)
            show_error "No GUI framework found (kdialog or zenity required)"
            return 1
            ;;
    esac
    
    case "$choice" in
        "performance"|"balanced"|"powersave"|"emergency"|"status")
            execute_power_command "$choice"
            ;;
        "ai-menu")
            ai_menu
            ;;
        *)
            # User cancelled
            ;;
    esac
}

# AI process management menu
ai_menu() {
    local gui="$(detect_gui)"
    local choice
    
    case "$gui" in
        "kdialog")
            choice=$(kdialog --menu "🤖 AI Process Manager" \
                "performance" "🚀 AI Performance - Max Speed" \
                "show" "📊 Show AI Processes" \
                "optimize" "⚖️ Optimize - Stability" \
                "restart" "🔄 Restart Services" \
                "emergency" "🚨 Emergency Stop" \
                "back" "← Back to Power Menu")
            ;;
        "zenity")
            choice=$(zenity --list --title="🤖 AI Process Manager" \
                --column="Action" --column="Description" \
                "performance" "🚀 AI Performance - Max Speed" \
                "show" "📊 Show AI Processes" \
                "optimize" "⚖️ Optimize - Stability" \
                "restart" "🔄 Restart Services" \
                "emergency" "🚨 Emergency Stop" \
                "back" "← Back to Power Menu" \
                --width=1000 --height=400)
            ;;
        *)
            show_error "No GUI framework found"
            return 1
            ;;
    esac
    
    case "$choice" in
        "performance"|"show"|"optimize"|"restart"|"emergency")
            execute_ai_command "$choice"
            ;;
        "back")
            power_menu
            ;;
        *)
            # User cancelled
            ;;
    esac
}

# Execute power management command
execute_power_command() {
    local command="$1"
    local output
    
    if [ ! -f "$PERFORMANCE_SCRIPT" ]; then
        show_error "Performance manager script not found: $PERFORMANCE_SCRIPT"
        return 1
    fi
    
    # Execute command and capture output
    if output=$("$PERFORMANCE_SCRIPT" "$command" 2>&1); then
        show_info "✅ Command executed successfully!\n\n$output"
    else
        show_error "❌ Command failed!\n\n$output"
    fi
    
    # Return to menu
    power_menu
}

# Execute AI command
execute_ai_command() {
    local command="$1"
    local output
    
    if [ ! -f "$AI_SCRIPT" ]; then
        show_error "AI manager script not found: $AI_SCRIPT"
        return 1
    fi
    
    # Execute command and capture output
    if output=$("$AI_SCRIPT" "$command" 2>&1); then
        show_info "✅ AI Command executed successfully!\n\n$output"
    else
        show_error "❌ AI Command failed!\n\n$output"
    fi
    
    # Return to AI menu
    ai_menu
}

# Main function
main() {
    local gui="$(detect_gui)"
    
    if [ "$gui" = "none" ]; then
        echo "ERROR: No GUI framework found!"
        echo "Please install kdialog (KDE) or zenity (GNOME/others)"
        exit 1
    fi
    
    power_menu
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi