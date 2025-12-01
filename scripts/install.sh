#!/bin/bash
set -euo pipefail
echo "🚀 Installing Power Management Suite..."
PROJECT_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
if ! sudo -n true 2>/dev/null; then echo "❌ Sudo required"; exit 1; fi
echo "📦 Installing dependencies..."
if command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y python3 lm-sensors; fi
chmod +x "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/src/frequency/*.py
sudo modprobe msr || true
echo "✅ Installation complete!"
