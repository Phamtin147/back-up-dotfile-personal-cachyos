# Dotfiles — CachyOS (Phamtin147)

Dotfiles cá nhân cho CachyOS (Arch-based), window manager **niri** + **Noctalia shell** (CachyOS desktop), GPU passthrough qua **QEMU/libvirt** (VM AutoVirt).

Repo này là backup **toàn diện** để chuyển máy: cài lại theo repo là máy mới y hệt máy cũ (loại trừ data/cache).

## Cấu trúc

```
dotfiles/
├── home/          # Các dotfile trong $HOME (.zshrc, .p10k.zsh, .gitconfig, Vial.conf, fix-usb-optional.sh...)
├── config/        # Nội dung ~/.config (niri, noctalia, alacritty, yazi, btop, ghostty, kitty, cava, Vial, obs-studio, qBittorrent...)
├── system/        # Cấu hình hệ thống /etc
│   ├── etc/       #   grub, mkinitcpio, modprobe.d (VFIO), udev (Vial), libvirt/qemu/AutoVirt.xml, legion_linux, fstab, pacman.conf...
│   └── packages/  #   Danh sách package + script cài lại (pacman explicit 255, AUR 33, flatpak)
├── patches/       # Patch QML cho Noctalia video wallpaper
└── install.sh     # Script cài đặt (symlink)
```

## Chuyển máy (restore từ đầu)

```bash
# 0. Cài CachyOS/Arch base + clone repo
git clone https://github.com/Phamtin147/back-up-dotfile-personal-cachyos.git ~/dotfiles
cd ~/dotfiles

# 1. Cài toàn bộ package (pacman + AUR + flatpak) — cần paru/yay
./system/packages/install-packages.sh

# 2. Symlink dotfiles vào $HOME và ~/.config
./install.sh

# 3. Cài cấu hình hệ thống (/etc, cần sudo)
sudo ./install.sh --with-system

# 4. Build lại initramfs + grub (kernel params IOMMU/VFIO)
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 5. Khôi phục VM AutoVirt (GPU passthrough)
sudo virsh define system/etc/libvirt/qemu/AutoVirt.xml
```

## Cài đặt (máy đang dùng)

```bash
# Xem trước các thao tác
./install.sh --dry-run

# Cài đặt vào $HOME
./install.sh

# Cài cả cấu hình hệ thống (/etc, cần sudo)
./install.sh --with-system
```

Cách hoạt động: install.sh tạo **symlink** từ repo vào `$HOME` và `~/.config`.
File/dir đã tồn tại sẽ được backup thành `*.bak` trước khi link.

## Yêu cầu

- CachyOS / Arch Linux (cấu hình `/etc` dành riêng cho CachyOS)
- zsh + Powerlevel10k
- niri (Wayland compositor)
- Noctalia shell (CachyOS)
- paru/yay (cài package AUR)

## Ghi chú

- **VM AutoVirt**: chỉ backup file XML định nghĩa VM (trong `system/etc/libvirt/qemu/`). Disk image + ISO (~4.6G trong `~/.local/share/libvirt`) là data, backup riêng ngoài repo.
- **AutoVirt tool**: dự án upstream riêng (github.com/Scrut1ny/AutoVirt), clone riêng, không nằm trong repo này.
- `.zshrc` tham chiếu `$HOME/cachyos-config.zsh` (nằm trong `home/`)
- Patch wallpaper: `./home/apply-wallpaper-patch.sh` (cần sudo, copy patches vào `/etc/xdg/quickshell/noctalia-shell`)
- Một số config chứa đường dẫn riêng của máy (VD: `WLR_DRM_DEVICES` trong `.zprofile`, `/etc/fstab`) — chỉnh lại nếu dùng máy khác
- **Không** đưa vào repo (secret/data/cache): `~/.config/opencode` (API key), `~/.config/gh` (token), browser profiles (Chrome/Brave/zen), `Code`/`Antigravity`/`unityhub` caches, `spicetify`, torrent data (`qBittorrent-data.conf`), `darktable` DB, VM disk images
