# 🚀 Full Backup CachyOS Dotfiles (Personal Setup)

Bản sao lưu **100% đầy đủ** toàn bộ môi trường làm việc cá nhân trên CachyOS / Arch Linux:
- **Giao diện & Compositor:** Niri, Hyprlock, Noctalia (Material You Dynamic Theming), Cava, QuickShell
- **Terminal & Shell:** Alacritty, Ghostty, Kitty, Zsh + Powerlevel10k, Yazi, Btop
- **Giao diện & Assets:** Fonts (MesloLGS NF), Icon theme (Delight-2), Cursor (Skyrim-cursors), GTK Themes, 1.3GB Wallpapers
- **Ứng dụng & Cấu hình:** Antigravity IDE, VSCode, Fcitx5, OBS Studio, qBittorrent, Vial, v.v.
- **Tự động hóa:** Bộ script tùy biến cho Hyprlock, Visualizer, Niri shader, Noctalia sync, Wallpaper switcher (`vwall`).

---

## ⚡ 1. Hướng dẫn Khôi phục trên Máy mới (1-Click Restore)

### Bước 1: Clone repo về máy mới
```bash
git clone https://github.com/Phamtin147/back-up-dotfile-personal-cachyos.git ~/back-up-dotfile-personal-cachyos
cd ~/back-up-dotfile-personal-cachyos
```

### Bước 2: Cài đặt và khôi phục toàn bộ

#### Cách 1: Khôi phục tất cả (Bao gồm tự động cài Packages từ Pacman, AUR, Flatpak)
```bash
./install.sh --with-packages
```

#### Cách 2: Chỉ khôi phục Config, Fonts, Icons, Wallpapers, Scripts (Nếu máy đã có đủ phần mềm)
```bash
./install.sh
```

#### Cài đặt thêm cấu hình hệ thống (`/etc` - GRUB, VFIO, udev rules... cần sudo):
```bash
./install.sh --with-system
# hoặc kết hợp tất cả:
./install.sh --all
```

---

## 🔄 2. Cập nhật và Sao lưu thêm trong tương lai (1-Click Backup)

Mỗi khi bạn cài thêm phần mềm mới, sửa đổi cấu hình hoặc thêm hình nền/script trên máy, chỉ cần chạy:

```bash
cd ~/back-up-dotfile-personal-cachyos
./backup.sh
git add -A
git commit -m "feat(backup): sync latest configs, packages and assets"
git push
```

---

## 📂 3. Cấu trúc thư mục

```
├── backup.sh                # Script tự động quét và sao lưu 100% máy hiện tại
├── install.sh               # Script tự động khôi phục và liên kết vào máy mới
├── home/                    # Các file trong $HOME (.zshrc, .p10k.zsh, .gitconfig...)
├── config/                  # Cấu hình ~/.config (noctalia, niri, hypr, alacritty, yazi...)
├── scripts/                 # Toàn bộ script trong ~/.local/bin
├── fonts/                   # Phông chữ hệ thống (~/.local/share/fonts)
├── icons/                   # Bộ icon & cursor (~/.icons)
├── themes/                  # Giao diện GTK (~/.themes)
├── wallpapers/              # Kho hình nền động tạo màu cho Noctalia (~/Pictures/Wallpapers)
├── shaders/                 # GLSL Shaders (~/shaders)
├── desktop/                 # Custom .desktop launchers (~/.local/share/applications)
└── system/
    ├── dconf/               # Bản sao lưu cấu hình GNOME/GTK dconf
    ├── packages/            # Danh sách gói phần mềm (Pacman, AUR, Flatpak)
    └── etc/                 # Cấu hình hệ thống /etc
```
