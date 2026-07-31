#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="${SCRIPT_DIR}/../patches"

SRC_DIR="/etc/xdg/quickshell/noctalia-shell"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d_%H%M%S)"

echo "=== Noctalia Video Wallpaper Patch ==="

# 1. Backup
echo "[1/4] Backing up originals..."
cp "$SRC_DIR/Modules/Background/Background.qml" "$SRC_DIR/Modules/Background/Background.qml$BACKUP_SUFFIX"
cp "$SRC_DIR/Modules/Background/Overview.qml" "$SRC_DIR/Modules/Background/Overview.qml$BACKUP_SUFFIX"
cp "$SRC_DIR/Services/UI/ImageCacheService.qml" "$SRC_DIR/Services/UI/ImageCacheService.qml$BACKUP_SUFFIX"
echo "  -> OK"

# 2. Copy patches
echo "[2/4] Applying patches..."
cp "$PATCH_DIR/Background.qml.patched" "$SRC_DIR/Modules/Background/Background.qml"
cp "$PATCH_DIR/Overview.qml.patched" "$SRC_DIR/Modules/Background/Overview.qml"
cp "$PATCH_DIR/ImageCacheService.qml.patched" "$SRC_DIR/Services/UI/ImageCacheService.qml"
echo "  -> OK"

# 3. Restart Noctalia
echo "[3/4] Restarting Noctalia..."
pkill -f "qs -c noctalia-shell" 2>/dev/null || true
echo "  -> OK"

# 4. Keybind info
echo "[4/4] Done!"
echo ""
echo "Muon dung Mod+Shift+D de mo wallpaper picker:"
echo "  Sua ~/.config/niri/cfg/keybinds.kdl dong 19 thanh:"
echo '    MOD+SHIFT+D  hotkey-overlay-title="Wallpaper" { spawn-sh "qs -c noctalia-shell ipc call wallpaper toggle"; }'
echo "  Sau do: niri msg action reload-config"
