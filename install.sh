#!/bin/bash

#==============================================================================
# PowerManagement Installation Script
# One-click installation for universal power management system
#==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Installation directory
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#==============================================================================
# Header
#==============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  PowerManagement Installation${NC}"
echo -e "${BLUE}  Version 3.1 - Universal Edition${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${YELLOW}Installation directory: $INSTALL_DIR${NC}"
echo ""

#==============================================================================
# Check Requirements
#==============================================================================

echo -e "${BLUE}📋 Checking requirements...${NC}"
echo ""

# Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo -e "  🐍 Python: $PYTHON_VERSION"

if ! python3 -c 'import sys; exit(0 if sys.version_info >= (3, 6) else 1)' 2>/dev/null; then
    echo -e "${RED}  ❌ Python 3.6+ required${NC}"
    exit 1
fi

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}  ⚠️  Running as root - will install system-wide${NC}"
    INSTALL_MODE="system"
else
    echo -e "${GREEN}  ✅ Running as user - will install for current user${NC}"
    INSTALL_MODE="user"
fi

echo ""

#==============================================================================
# Install Python Dependencies
#==============================================================================

echo -e "${BLUE}📦 Installing Python dependencies...${NC}"
echo ""

# Check psutil
if python3 -c 'import psutil' 2>/dev/null; then
    echo -e "  ✅ psutil already installed"
else
    echo -e "  📥 Installing psutil..."
    if [ "$INSTALL_MODE" = "system" ]; then
        pip3 install psutil || apt-get install -y python3-psutil
    else
        pip3 install --user psutil
    fi
    echo -e "  ✅ psutil installed"
fi

echo ""

#==============================================================================
# Install Optional Dependencies
#==============================================================================

echo -e "${BLUE}🔧 Checking optional dependencies...${NC}"
echo ""

# lm-sensors
if command -v sensors >/dev/null 2>&1; then
    echo -e "  ✅ lm-sensors installed"
else
    echo -e "  ⚠️  lm-sensors not found (recommended for full sensor support)"
    echo -e "     Install with: sudo apt install lm-sensors"
fi

# nvidia-smi
if command -v nvidia-smi >/dev/null 2>&1; then
    echo -e "  ✅ nvidia-smi installed (NVIDIA GPU support enabled)"
else
    echo -e "  ℹ️  nvidia-smi not found (NVIDIA GPU support disabled)"
fi

# nvidia-settings
if command -v nvidia-settings >/dev/null 2>&1; then
    echo -e "  ✅ nvidia-settings installed (NVIDIA fan control enabled)"
else
    echo -e "  ℹ️  nvidia-settings not found (NVIDIA fan control disabled)"
fi

echo ""

#==============================================================================
# Hardware Detection
#==============================================================================

echo -e "${BLUE}🔍 Detecting hardware...${NC}"
echo ""

export PYTHONPATH="$INSTALL_DIR/src:${PYTHONPATH:-}"

# Run hardware detection
python3 "$INSTALL_DIR/src/hardware/hardware_detector.py" 2>/dev/null | head -20 || echo "  ℹ️  Limited hardware detection (may need root)"

echo ""

#==============================================================================
# Create Symlinks (Optional)
#==============================================================================

echo -e "${BLUE}🔗 Creating convenient shortcuts...${NC}"
echo ""

# Create local bin directory if needed
if [ "$INSTALL_MODE" = "user" ]; then
    mkdir -p "$HOME/.local/bin"
    BIN_DIR="$HOME/.local/bin"
else
    BIN_DIR="/usr/local/bin"
fi

# Create symlinks
echo -e "  Creating shortcuts in $BIN_DIR..."

# Performance manager
if [ -f "$INSTALL_DIR/scripts/performance_manager.sh" ]; then
    ln -sf "$INSTALL_DIR/scripts/performance_manager.sh" "$BIN_DIR/power-manager" 2>/dev/null || echo "  ⚠️  Could not create power-manager symlink (may need sudo)"
fi

# GPU monitor
cat > "$BIN_DIR/gpu-monitor" << EOF
#!/bin/bash
PYTHONPATH="$INSTALL_DIR/src" python3 "$INSTALL_DIR/src/sensors/gpu_monitor.py" "\$@"
EOF
chmod +x "$BIN_DIR/gpu-monitor" 2>/dev/null || echo "  ⚠️  Could not create gpu-monitor (may need sudo)"

# Sensor detector
cat > "$BIN_DIR/sensor-detector" << EOF
#!/bin/bash
PYTHONPATH="$INSTALL_DIR/src" python3 "$INSTALL_DIR/src/sensors/universal_sensor_detector.py" "\$@"
EOF
chmod +x "$BIN_DIR/sensor-detector" 2>/dev/null || echo "  ⚠️  Could not create sensor-detector (may need sudo)"

# Fan controller
cat > "$BIN_DIR/fan-control" << EOF
#!/bin/bash
PYTHONPATH="$INSTALL_DIR/src" python3 "$INSTALL_DIR/src/sensors/fan_controller.py" "\$@"
EOF
chmod +x "$BIN_DIR/fan-control" 2>/dev/null || echo "  ⚠️  Could not create fan-control (may need sudo)"

echo -e "  ✅ Shortcuts created"

# Add to PATH message
if [ "$INSTALL_MODE" = "user" ]; then
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo -e "  ${YELLOW}⚠️  Add $HOME/.local/bin to PATH:${NC}"
        echo -e "     ${BLUE}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc${NC}"
        echo -e "     ${BLUE}source ~/.bashrc${NC}"
    fi
fi

echo ""

#==============================================================================
# Run Tests
#==============================================================================

echo -e "${BLUE}🧪 Running tests...${NC}"
echo ""

if [ -f "$INSTALL_DIR/tests/test_sensors.sh" ]; then
    bash "$INSTALL_DIR/tests/test_sensors.sh" || echo -e "${YELLOW}  ⚠️  Some tests failed (may be expected in limited environments)${NC}"
else
    echo -e "${YELLOW}  ⚠️  Test suite not found${NC}"
fi

echo ""

#==============================================================================
# Installation Complete
#==============================================================================

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${BLUE}📚 Quick Start:${NC}"
echo ""
echo -e "  ${YELLOW}Show GPU metrics:${NC}"
echo -e "    gpu-monitor"
echo ""
echo -e "  ${YELLOW}Show all sensors:${NC}"
echo -e "    sensor-detector"
echo ""
echo -e "  ${YELLOW}Show fan status:${NC}"
echo -e "    fan-control status"
echo ""
echo -e "  ${YELLOW}Set power profile:${NC}"
echo -e "    power-manager performance"
echo -e "    power-manager balanced"
echo -e "    power-manager powersave"
echo ""
echo -e "  ${YELLOW}Start monitoring service:${NC}"
echo -e "    PYTHONPATH=\"$INSTALL_DIR/src\" python3 $INSTALL_DIR/src/services/monitoring_service.py"
echo ""
echo -e "${BLUE}📖 Documentation:${NC}"
echo -e "  - docs/SENSOR_MONITORING.md - Sensor & fan control guide"
echo -e "  - docs/UNIVERSAL_HARDWARE.md - Hardware compatibility"
echo -e "  - README.md - Main documentation"
echo ""
echo -e "${GREEN}🎉 Enjoy PowerManagement!${NC}"
echo ""
