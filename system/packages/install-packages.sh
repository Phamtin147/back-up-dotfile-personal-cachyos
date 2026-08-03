#!/bin/bash
# Cài lại toàn bộ package để máy mới giống máy cũ.
# Chạy trên CachyOS/Arch đã cài base, sau khi clone dotfiles repo.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 1. Cài package chính thức (pacman) — $(wc -l < "$DIR/pacman-explicit.txt") gói"
sudo pacman -S --needed --noconfirm - < "$DIR/pacman-explicit.txt"

if command -v paru >/dev/null 2>&1; then
    AUR_HELPER=paru
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER=yay
else
    echo "==> Chưa có paru/yay. Cài paru-bin trước rồi chạy lại script."
    exit 1
fi

echo "==> 2. Cài package AUR ($AUR_HELPER) — $(wc -l < "$DIR/pacman-aur.txt") gói"
$AUR_HELPER -S --needed --noconfirm - < "$DIR/pacman-aur.txt"

echo "==> 3. Cài Flatpak apps — $(wc -l < "$DIR/flatpak.txt") app"
while IFS= read -r app; do
    [ -n "$app" ] && flatpak install -y --noninteractive flathub "$app"
done < "$DIR/flatpak.txt"

echo ""
echo "Xong! Tiếp theo:"
echo "  ./install.sh            # symlink dotfiles vào \$HOME và ~/.config"
echo "  sudo ./install.sh --with-system   # cấu hình /etc (grub, VFIO, libvirt...)"
echo "  sudo mkinitcpio -P     # rebuild initramfs (nếu đổi modprobe/mkinitcpio)"
echo "  sudo grub-mkconfig -o /boot/grub/grub.cfg   # nếu đổi kernel params"
echo "  sudo virsh define system/etc/libvirt/qemu/AutoVirt.xml   # khôi phục VM"
