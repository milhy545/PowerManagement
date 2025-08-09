#!/bin/bash

# Plasma Config Cleaner - Remove broken widget references
# Version: 1.0

set -euo pipefail

readonly CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
readonly BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

log() {
    echo "$(date '+%H:%M:%S') [ConfigClean] $*"
}

# Backup config
backup_config() {
    log "📦 Backing up Plasma config..."
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    log "✅ Backup saved: $BACKUP_FILE"
}

# Remove broken Gemini widget references
clean_broken_widgets() {
    log "🧹 Removing broken widget references..."
    
    # Create temporary file without broken references
    local temp_file=$(mktemp)
    
    # Remove section [Containments][2][Applets][35] and its subsections
    awk '
    BEGIN { skip = 0; in_section = 0 }
    /^\[Containments\]\[2\]\[Applets\]\[35\]/ { skip = 1; in_section = 1; next }
    /^\[Containments\]\[2\]\[Applets\]\[35\]\[/ { skip = 1; next }
    /^\[/ { 
        if (in_section && !/^\[Containments\]\[2\]\[Applets\]\[35\]/) {
            skip = 0; in_section = 0 
        }
    }
    /^AppletOrder=/ {
        if (!skip) {
            gsub(/;35/, "")
            gsub(/35;/, "")
            gsub(/^35$/, "")
        }
    }
    !skip { print }
    ' "$CONFIG_FILE" > "$temp_file"
    
    # Replace original with cleaned version
    mv "$temp_file" "$CONFIG_FILE"
    
    log "✅ Broken widget references removed"
}

# Show config status
show_status() {
    log "📋 Current widget status:"
    echo ""
    
    echo "🟢 Active widgets in panel:"
    grep -E "^\[Containments\]\[2\]\[Applets\]\[[0-9]+\]$" "$CONFIG_FILE" | while read -r line; do
        local applet_id=$(echo "$line" | grep -o '\[2\]\[Applets\]\[[0-9]*\]' | grep -o '[0-9]*')
        local plugin=$(awk -v id="$applet_id" '
            $0 ~ "^\\[Containments\\]\\[2\\]\\[Applets\\]\\[" id "\\]$" { found=1; next }
            found && /^plugin=/ { print $0; found=0 }
            found && /^\[/ && !/^\[Containments\]\[2\]\[Applets\]\[/ { found=0 }
        ' "$CONFIG_FILE" | cut -d= -f2)
        
        if [ -n "$plugin" ]; then
            echo "  [$applet_id] $plugin"
        fi
    done
    echo ""
    
    echo "🔍 AppletOrder:"
    grep "^AppletOrder=" "$CONFIG_FILE" | head -1
    echo ""
    
    echo "❌ Broken references:"
    if grep -q "com.samirgaire10.google_gemini-plasma6" "$CONFIG_FILE"; then
        echo "  Found broken Gemini widget reference"
    else
        echo "  None found"
    fi
}

# Restart Plasma after cleaning
restart_plasma() {
    log "🔄 Restarting Plasma to apply changes..."
    /home/milhy777/Develop/PowerManagement/scripts/plasma_restart.sh restart
}

# Main menu
main() {
    case "${1:-}" in
        "clean")
            backup_config
            clean_broken_widgets
            show_status
            log "💡 Run 'restart' to apply changes"
            ;;
        "restart")
            restart_plasma
            ;;
        "fix")
            backup_config
            clean_broken_widgets
            restart_plasma
            ;;
        "status")
            show_status
            ;;
        "backup")
            backup_config
            ;;
        *)
            echo "🧹 Plasma Config Cleaner"
            echo "Usage: $0 {clean|restart|fix|status|backup}"
            echo ""
            echo "Commands:"
            echo "  clean    - Remove broken widget references (with backup)"
            echo "  restart  - Restart Plasma"
            echo "  fix      - Clean + restart (complete fix)"
            echo "  status   - Show current widget status"
            echo "  backup   - Backup config only"
            echo ""
            show_status
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi