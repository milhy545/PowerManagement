#!/bin/bash

# Fix Gemini Plasmoid Crashes - QtWebEngine Problem
# Version: 1.0

set -euo pipefail

readonly PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids"
readonly BACKUP_DIR="$HOME/.local/share/plasma/plasmoids-backup"

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [Gemini-Fix] $*"
}

# Backup problematic plasmoids
backup_plasmoids() {
    log "🔒 Backing up potentially problematic plasmoids..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup all Gemini plasmoids
    for plasmoid in "$PLASMOID_DIR"/com.samirgaire10.*gemini*; do
        if [ -d "$plasmoid" ]; then
            local name=$(basename "$plasmoid")
            log "📦 Backing up: $name"
            cp -r "$plasmoid" "$BACKUP_DIR/"
        fi
    done
    
    log "✅ Backup completed to: $BACKUP_DIR"
}

# Disable problematic plasmoids
disable_gemini_plasmoids() {
    log "🚫 Disabling problematic Gemini plasmoids..."
    
    for plasmoid in "$PLASMOID_DIR"/com.samirgaire10.*gemini*; do
        if [ -d "$plasmoid" ]; then
            local name=$(basename "$plasmoid")
            log "🔧 Disabling: $name"
            
            # Rename to .disabled
            mv "$plasmoid" "${plasmoid}.disabled"
        fi
    done
    
    log "✅ Problematic plasmoids disabled"
}

# Create safe Gemini replacement
create_safe_gemini() {
    log "🛡️ Creating safe Gemini replacement..."
    
    local safe_dir="$PLASMOID_DIR/com.powertools.gemini.safe"
    mkdir -p "$safe_dir/contents/ui"
    
    # Safe metadata without QtWebEngine
    cat > "$safe_dir/metadata.json" << 'EOF'
{
    "KPackageStructure": "Plasma/Applet",
    "KPlugin": {
        "Authors": [
            {
                "Name": "PowerTools Team"
            }
        ],
        "Category": "Online Services",
        "Description": "Safe Gemini launcher (no crashes!)",
        "Icon": "applications-development",
        "Id": "com.powertools.gemini.safe",
        "License": "MIT",
        "Name": "Safe Gemini Launcher",
        "Website": "https://github.com/powertools/safe-gemini"
    },
    "X-Plasma-API-Minimum-Version": "6.0"
}
EOF

    # Safe QML without QtWebEngine
    cat > "$safe_dir/contents/ui/main.qml" << 'EOF'
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
            // Safe external browser launch instead of QtWebEngine
            Qt.openUrlExternally("https://gemini.google.com/")
        }
        
        ToolTip.text: "Open Gemini AI in browser (safe mode)"
    }
    
    fullRepresentation: ColumnLayout {
        PlasmaComponents.Label {
            text: "🛡️ Safe Gemini Launcher"
            Layout.alignment: Qt.AlignHCenter
            font.bold: true
        }
        
        PlasmaComponents.Label {
            text: "Prevents Plasma crashes"
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: 9
            opacity: 0.7
        }
        
        PlasmaComponents.Button {
            text: "🚀 Open Gemini"
            Layout.fillWidth: true
            onClicked: Qt.openUrlExternally("https://gemini.google.com/")
        }
        
        PlasmaComponents.Button {
            text: "⚡ AI Performance Mode"
            Layout.fillWidth: true
            onClicked: {
                var cmd = "/home/milhy777/ai_process_manager.sh performance";
                executable.exec(cmd);
            }
        }
    }
    
    // Safe command execution
    PlasmaCore.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        
        function exec(cmd) {
            connectSource(cmd)
        }
    }
}
EOF

    log "✅ Safe Gemini replacement created"
}

# Restart Plasma to apply changes
restart_plasma() {
    log "🔄 Restarting Plasma to apply changes..."
    
    # Gentle restart
    kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null || true
    
    log "💡 For complete fix, restart KDE session or run:"
    log "   # Plasma 6:"
    log "   kquitapp6 plasmashell && plasmashell &"
    log "   # Or Plasma 5:"
    log "   kquitapp5 plasmashell && kstart5 plasmashell"
    log "   # Or simply logout/login"
}

# Restore from backup
restore_plasmoids() {
    log "🔄 Restoring plasmoids from backup..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log "❌ No backup found at: $BACKUP_DIR"
        return 1
    fi
    
    # Remove .disabled versions
    rm -rf "$PLASMOID_DIR"/com.samirgaire10.*gemini*.disabled 2>/dev/null || true
    
    # Restore from backup
    for backup in "$BACKUP_DIR"/com.samirgaire10.*gemini*; do
        if [ -d "$backup" ]; then
            local name=$(basename "$backup")
            log "📦 Restoring: $name"
            cp -r "$backup" "$PLASMOID_DIR/"
        fi
    done
    
    log "✅ Plasmoids restored"
}

# Main menu
main() {
    case "${1:-}" in
        "fix")
            backup_plasmoids
            disable_gemini_plasmoids
            create_safe_gemini
            restart_plasma
            ;;
        "restore")
            restore_plasmoids
            restart_plasma
            ;;
        "backup")
            backup_plasmoids
            ;;
        "disable")
            disable_gemini_plasmoids
            restart_plasma
            ;;
        "status")
            echo "🔍 Gemini Plasmoid Status:"
            echo ""
            echo "Problematic plasmoids:"
            ls -la "$PLASMOID_DIR"/com.samirgaire10.*gemini* 2>/dev/null || echo "  None found"
            echo ""
            echo "Disabled plasmoids:"
            ls -la "$PLASMOID_DIR"/com.samirgaire10.*gemini*.disabled 2>/dev/null || echo "  None found"
            echo ""
            echo "Safe replacement:"
            ls -la "$PLASMOID_DIR"/com.powertools.gemini.safe 2>/dev/null || echo "  Not installed"
            ;;
        *)
            echo "🛡️ Gemini Plasmoid Crash Fix"
            echo "Usage: $0 {fix|restore|backup|disable|status}"
            echo ""
            echo "Commands:"
            echo "  fix      - Fix crashes (backup + disable + create safe version)"
            echo "  restore  - Restore original plasmoids from backup"
            echo "  backup   - Backup plasmoids only"
            echo "  disable  - Disable problematic plasmoids only"
            echo "  status   - Show current status"
            echo ""
            echo "💡 Recommended: Use 'fix' to solve Plasma crashes"
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi