# Dotfiles — CachyOS (Phamtin147)

Dotfiles cá nhân cho CachyOS (Arch-based), window manager **niri** + **Noctalia shell** (CachyOS desktop).

## Cấu trúc

```
dotfiles/
├── home/          # Các dotfile trong $HOME (.zshrc, .p10k.zsh, .gitconfig...)
├── config/        # Nội dung ~/.config (niri, alacritty, yazi, btop, fcitx5...)
├── system/        # Cấu hình hệ thống /etc (X11, environment, legion_linux...)
├── patches/       # Patch QML cho Noctalia video wallpaper
└── install.sh     # Script cài đặt (symlink)
```

## Cài đặt

```bash
git clone https://github.com/Phamtin147/back-up-dotfile-personal-cachyos.git ~/dotfiles
cd ~/dotfiles

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

## Ghi chú

- `.zshrc` tham chiếu `$HOME/cachyos-config.zsh` (nằm trong `home/`)
- Patch wallpaper: `./home/apply-wallpaper-patch.sh` (cần sudo, copy patches vào `/etc/xdg/quickshell/noctalia-shell`)
- Một số config chứa đường dẫn riêng của máy (VD: `WLR_DRM_DEVICES` trong `.zprofile`) — chỉnh lại nếu dùng máy khác
- Bỏ qua `~/.config/opencode/node_modules` (57M) để repo gọn
- **Không** đưa `~/.config/opencode` vào repo vì chứa API key — kiểm tra lại trước khi thêm bất kỳ config nào khác
