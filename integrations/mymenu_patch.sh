#!/bin/bash

#==============================================================================
# MyMenu Integration Patch
# Adds PowerManagement category to MyMenu dmenu-launcher.sh
#==============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  MyMenu PowerManagement Integration${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Find MyMenu installation
MYMENU_DIR="${1:-/home/user/MyMenu}"

if [ ! -f "$MYMENU_DIR/dmenu-launcher.sh" ]; then
    echo -e "${YELLOW}❌ MyMenu not found at: $MYMENU_DIR${NC}"
    echo -e "${YELLOW}Usage: $0 /path/to/MyMenu${NC}"
    exit 1
fi

echo -e "${BLUE}📁 MyMenu found: $MYMENU_DIR${NC}"
echo ""

# Detect PowerManagement installation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWER_MGMT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}⚡ PowerManagement: $POWER_MGMT_DIR${NC}"
echo ""

# Create backup
BACKUP_FILE="$MYMENU_DIR/dmenu-launcher.sh.backup.$(date +%Y%m%d_%H%M%S)"
cp "$MYMENU_DIR/dmenu-launcher.sh" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
echo ""

# Create PowerManagement category addition
cat > "/tmp/power_mgmt_category.sh" << 'EOF'

#==============================================================================
# PowerManagement Integration - Auto-generated
#==============================================================================

show_power_management_menu() {
    cat << MENU
🔥 Performance Mode
⚖️ Balanced Mode
🔋 Power Save Mode
🚨 Emergency Mode
---
📊 Current Status
🎮 GPU Metrics
🌡️ All Sensors
💨 Fan Status
💨 Fan Control
---
📈 Start Monitoring
📖 Documentation
MENU
}

handle_power_management() {
    local choice="$1"
    local integration="POWER_MGMT_INTEGRATION_PATH"

    case "$choice" in
        "🔥 Performance Mode")
            $integration performance
            ;;
        "⚖️ Balanced Mode")
            $integration balanced
            ;;
        "🔋 Power Save Mode")
            $integration powersave
            ;;
        "🚨 Emergency Mode")
            $integration emergency
            ;;
        "📊 Current Status")
            $integration status
            ;;
        "🎮 GPU Metrics")
            $integration gpu
            ;;
        "🌡️ All Sensors")
            $integration sensors
            ;;
        "💨 Fan Status")
            $integration fans
            ;;
        "💨 Fan Control")
            # Show fan submenu
            local fan_choice=$(echo -e "🌀 30% Silent\n🌀 50% Normal\n🌀 75% High\n🌀 100% Max\n🔄 Auto Mode" | dmenu -i -p "Fan Control:")
            case "$fan_choice" in
                "🌀 30% Silent") $integration fan-30 ;;
                "🌀 50% Normal") $integration fan-50 ;;
                "🌀 75% High") $integration fan-75 ;;
                "🌀 100% Max") $integration fan-100 ;;
                "🔄 Auto Mode") $integration fan-auto ;;
            esac
            ;;
        "📈 Start Monitoring")
            $integration monitoring
            ;;
        "📖 Documentation")
            $integration docs
            ;;
    esac
}
EOF

# Replace placeholder with actual path
sed -i "s|POWER_MGMT_INTEGRATION_PATH|$POWER_MGMT_DIR/integrations/mymenu_integration.sh|g" /tmp/power_mgmt_category.sh

echo -e "${BLUE}🔧 Adding PowerManagement category to MyMenu...${NC}"
echo ""

# Check if already integrated
if grep -q "PowerManagement Integration" "$MYMENU_DIR/dmenu-launcher.sh"; then
    echo -e "${YELLOW}⚠️  PowerManagement already integrated${NC}"
    echo -e "${YELLOW}   Remove existing integration first${NC}"
    exit 1
fi

# Add integration code before final line
# Find the line before "esac" at the end
LINE_NUM=$(grep -n "^esac$" "$MYMENU_DIR/dmenu-launcher.sh" | tail -1 | cut -d: -f1)

if [ -z "$LINE_NUM" ]; then
    echo -e "${YELLOW}❌ Could not find insertion point${NC}"
    exit 1
fi

# Insert before that line
head -n $((LINE_NUM - 1)) "$MYMENU_DIR/dmenu-launcher.sh" > /tmp/dmenu_new.sh
cat /tmp/power_mgmt_category.sh >> /tmp/dmenu_new.sh
tail -n +$LINE_NUM "$MYMENU_DIR/dmenu-launcher.sh" >> /tmp/dmenu_new.sh

# Add category to main menu (after line with main categories)
# Find monitoring category and add power management after it
sed -i '/📊 Monitoring/a 🌡️ Power & Thermal' /tmp/dmenu_new.sh

# Add handler in main switch
sed -i '/handle_monitoring_menu/a \        "🌡️ Power & Thermal")\n            local pm_choice=$(show_power_management_menu | dmenu -i -p "Power Management:")\n            [ -n "$pm_choice" ] \&\& handle_power_management "$pm_choice"\n            ;;' /tmp/dmenu_new.sh

# Replace original
mv /tmp/dmenu_new.sh "$MYMENU_DIR/dmenu-launcher.sh"
chmod +x "$MYMENU_DIR/dmenu-launcher.sh"

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ Integration Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${BLUE}📋 What was added:${NC}"
echo -e "  • 🌡️ Power & Thermal category in main menu"
echo -e "  • 11 power management actions"
echo -e "  • GPU monitoring"
echo -e "  • Sensor detection"
echo -e "  • Fan control"
echo -e "  • Monitoring service launcher"
echo ""
echo -e "${BLUE}🚀 Usage:${NC}"
echo -e "  Run: $MYMENU_DIR/dmenu-launcher.sh"
echo -e "  Select: 🌡️ Power & Thermal"
echo ""
echo -e "${YELLOW}💾 Backup saved: $(basename $BACKUP_FILE)${NC}"
echo ""
