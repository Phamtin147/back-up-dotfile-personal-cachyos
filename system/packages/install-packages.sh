#!/usr/bin/env bash
# ==============================================================================
# Script Cài đặt toàn bộ Package (Pacman + AUR + Flatpak) cho máy mới
# ==============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 1. Cài đặt các gói chính thức (Pacman)..."
if [ -f "$DIR/pacman-explicit.txt" ]; then
    echo "    Số lượng gói: $(wc -l < "$DIR/pacman-explicit.txt")"
    sudo pacman -S --needed --noconfirm - < "$DIR/pacman-explicit.txt" || {
        echo "⚠️ Có một số gói có thể thay đổi tên hoặc đã có sẵn, đang tiếp tục..."
    }
fi

echo "==> 2. Cài đặt các gói AUR..."
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER=paru
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER=yay
else
    echo "    Chưa có paru/yay. Đang tự động build paru-bin..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    (cd /tmp/paru-bin && makepkg -si --noconfirm)
    rm -rf /tmp/paru-bin
    AUR_HELPER=paru
fi

if [ -f "$DIR/pacman-aur.txt" ]; then
    echo "    Dùng $AUR_HELPER cài đặt $(wc -l < "$DIR/pacman-aur.txt") gói AUR..."
    $AUR_HELPER -S --needed --noconfirm - < "$DIR/pacman-aur.txt" || true
fi

echo "==> 3. Cài đặt các ứng dụng Flatpak..."
if [ -f "$DIR/flatpak.txt" ] && command -v flatpak >/dev/null 2>&1; then
    while IFS= read -r app; do
        [ -n "$app" ] && flatpak install -y --noninteractive flathub "$app" || true
    done < "$DIR/flatpak.txt"
fi

echo "==> Hoàn tất cài đặt toàn bộ gói phần mềm!"
