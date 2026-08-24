#!/usr/bin/env bash
# ==============================================================================
# Script Full Backup toàn bộ cấu hình CachyOS / Arch Linux
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Bắt đầu sao lưu toàn bộ cấu hình máy vào: $DOTFILES_DIR"

# 1. Dọn dẹp thư mục trùng lặp cũ
rm -rf "$DOTFILES_DIR/.config"
rm -f "$DOTFILES_DIR/config/antigravity-css-preload.js\""

# 2. Xuất danh sách phần mềm (Packages)
echo "==> [1/9] Xuất danh sách gói phần mềm..."
mkdir -p "$DOTFILES_DIR/system/packages"
if command -v pacman >/dev/null 2>&1; then
    pacman -Qqen > "$DOTFILES_DIR/system/packages/pacman-explicit.txt" || true
    pacman -Qqem > "$DOTFILES_DIR/system/packages/pacman-aur.txt" || true
fi
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application > "$DOTFILES_DIR/system/packages/flatpak.txt" || true
fi

# 3. Xuất dconf / GSettings
echo "==> [2/9] Xuất thiết lập hệ thống dconf..."
mkdir -p "$DOTFILES_DIR/system/dconf"
if command -v dconf >/dev/null 2>&1; then
    dconf dump / > "$DOTFILES_DIR/system/dconf/dconf-settings.ini" || true
fi

# 4. Sao lưu Dotfiles trong $HOME
echo "==> [3/9] Sao lưu dotfiles trong $HOME..."
mkdir -p "$DOTFILES_DIR/home"
for file in .zshrc .p10k.zsh .zprofile .gitconfig .npmrc cachyos-config.zsh; do
    if [ -f "$HOME/$file" ]; then
        cp -af "$HOME/$file" "$DOTFILES_DIR/home/"
    fi
done

# 5. Sao lưu ~/.config (Bao gồm Noctalia, Quickshell shell, Niri, Hypr, v.v.)
echo "==> [4/9] Sao lưu cấu hình ~/.config..."
mkdir -p "$DOTFILES_DIR/config"

CONFIG_ITEMS=(
    "noctalia"
    "quickshell"
    "hypr"
    "niri"
    "niri-screensaver"
    "cava"
    "alacritty"
    "ghostty"
    "kitty"
    "btop"
    "yazi"
    "gtk-3.0"
    "gtk-4.0"
    "qt6ct"
    "QtProject"
    "xsettingsd"
    "fcitx"
    "fcitx5"
    "fontconfig"
    "nwg-look"
    "qBittorrent"
    "obs-studio"
    "Vial"
    "autostart"
    "systemd"
    "weylus"
    "baloofileinformationrc"
    "dolphinrc"
    "filetypesrc"
    "kiorc"
    "mimeapps.list"
    "pavucontrol.ini"
    "user-dirs.dirs"
    "user-dirs.locale"
    "antigravity-css-preload.js"
    "antigravity-ide-flags.conf"
    "code-flags.conf"
)

for item in "${CONFIG_ITEMS[@]}"; do
    if [ -e "$HOME/.config/$item" ]; then
        rm -rf "$DOTFILES_DIR/config/$item"
        cp -afr "$HOME/.config/$item" "$DOTFILES_DIR/config/"
    fi
done

# Sao lưu settings VSCode / Antigravity IDE
mkdir -p "$DOTFILES_DIR/config/Antigravity/User" "$DOTFILES_DIR/config/Antigravity IDE/User" "$DOTFILES_DIR/config/vscode"
if [ -f "$HOME/.config/Antigravity/User/settings.json" ]; then
    cp -af "$HOME/.config/Antigravity/User/settings.json" "$DOTFILES_DIR/config/Antigravity/User/"
fi
if [ -f "$HOME/.config/Antigravity IDE/User/settings.json" ]; then
    cp -af "$HOME/.config/Antigravity IDE/User/settings.json" "$DOTFILES_DIR/config/Antigravity IDE/User/"
fi
if [ -f "$HOME/.config/Code/User/settings.json" ]; then
    cp -af "$HOME/.config/Code/User/settings.json" "$DOTFILES_DIR/config/vscode/"
fi

# Sao lưu CSS tùy biến
if [ -f "$HOME/vscode-custom.css" ]; then
    cp -af "$HOME/vscode-custom.css" "$DOTFILES_DIR/vscode-custom.css"
elif [ -f "$HOME/.config/vscode-custom.css" ]; then
    cp -af "$HOME/.config/vscode-custom.css" "$DOTFILES_DIR/vscode-custom.css"
fi

# 6. Sao lưu Noctalia Runtime & Widget State (~/.local/state/noctalia)
echo "==> [5/9] Sao lưu Noctalia State & Widget UI (~/.local/state/noctalia)..."
mkdir -p "$DOTFILES_DIR/state"
if [ -d "$HOME/.local/state/noctalia" ]; then
    rsync -a --delete "$HOME/.local/state/noctalia/" "$DOTFILES_DIR/state/noctalia/"
fi

# 7. Sao lưu VSCode / Antigravity Extensions (Noctalia theme extension)
echo "==> [6/9] Sao lưu Extensions cần thiết..."
mkdir -p "$DOTFILES_DIR/extensions"
for ext_dir in "$HOME/.vscode/extensions" "$HOME/.antigravity/extensions"; do
    if [ -d "$ext_dir" ]; then
        find "$ext_dir" -maxdepth 1 -name "*noctaliatheme*" -type d -exec cp -afr {} "$DOTFILES_DIR/extensions/" \; 2>/dev/null || true
    fi
done

# 8. Sao lưu Scripts ~/.local/bin
echo "==> [7/9] Sao lưu các scripts trong ~/.local/bin..."
mkdir -p "$DOTFILES_DIR/scripts/hyprlock" \
         "$DOTFILES_DIR/scripts/noctalia" \
         "$DOTFILES_DIR/scripts/niri" \
         "$DOTFILES_DIR/scripts/wallpaper" \
         "$DOTFILES_DIR/scripts/system"

# Hyprlock scripts
for s in hyprlock-visualizer hyprlock-cava-daemon hyprlock-cava hyprlock-media \
         hyprlock-bar-right hyprlock-battery-incidator hyprlock-system-info \
         waybar-now-playing lock-screen-shader hyprlock-cava-style hyprlock-cava-fast hyprlock-vis-read; do
    if [ -f "$HOME/.local/bin/$s" ]; then
        cp -af "$HOME/.local/bin/$s" "$DOTFILES_DIR/scripts/hyprlock/"
    fi
done

# Noctalia scripts
for s in noctalia-sync-antigravity.sh noctalia-sync-check.sh noctalia-shutdown; do
    if [ -f "$HOME/.local/bin/$s" ]; then
        cp -af "$HOME/.local/bin/$s" "$DOTFILES_DIR/scripts/noctalia/"
    fi
done

# Niri scripts
for s in niri-shader niri-screensaver niri-screensaver-ctl niri-screensaver-launch; do
    if [ -f "$HOME/.local/bin/$s" ]; then
        cp -af "$HOME/.local/bin/$s" "$DOTFILES_DIR/scripts/niri/"
    fi
done

# Wallpaper & System scripts
if [ -f "$HOME/.local/bin/vwall" ]; then
    cp -af "$HOME/.local/bin/vwall" "$DOTFILES_DIR/scripts/wallpaper/"
fi
if [ -f "$HOME/.local/bin/legion-startup.sh" ]; then
    cp -af "$HOME/.local/bin/legion-startup.sh" "$DOTFILES_DIR/scripts/system/"
fi

# 9. Sao lưu Fonts, Icons, Themes, Wallpapers, Desktop files, Shaders
echo "==> [8/9] Sao lưu Fonts, Icons, Themes, Wallpapers, Desktop files, Shaders..."
mkdir -p "$DOTFILES_DIR/fonts" "$DOTFILES_DIR/icons" "$DOTFILES_DIR/themes" "$DOTFILES_DIR/desktop" "$DOTFILES_DIR/wallpapers" "$DOTFILES_DIR/shaders"

# Fonts
if [ -d "$HOME/.local/share/fonts" ]; then
    rsync -a --delete "$HOME/.local/share/fonts/" "$DOTFILES_DIR/fonts/"
fi

# Icons & Cursors
if [ -d "$HOME/.icons" ]; then
    rsync -a --delete "$HOME/.icons/" "$DOTFILES_DIR/icons/"
fi

# Themes
if [ -d "$HOME/.themes" ]; then
    rsync -a --delete "$HOME/.themes/" "$DOTFILES_DIR/themes/"
fi

# Desktop entries
if [ -d "$HOME/.local/share/applications" ]; then
    rsync -a "$HOME/.local/share/applications/" "$DOTFILES_DIR/desktop/"
fi

# Shaders
if [ -d "$HOME/shaders" ]; then
    rsync -a --delete "$HOME/shaders/" "$DOTFILES_DIR/shaders/"
fi

# Xóa các thư mục .git lồng nhau để đảm bảo toàn bộ file được track đầy đủ
find "$DOTFILES_DIR/icons" "$DOTFILES_DIR/themes" "$DOTFILES_DIR/state" "$DOTFILES_DIR/extensions" -name ".git" -type d -prune -exec rm -rf {} + 2>/dev/null || true

# Wallpapers
if [ -d "$HOME/Pictures/Wallpapers" ]; then
    echo "    Đang sao lưu kho hình nền (~1.3GB)..."
    rsync -a --delete "$HOME/Pictures/Wallpapers/" "$DOTFILES_DIR/wallpapers/"
fi

# Phân quyền thực thi
find "$DOTFILES_DIR/scripts" -type f -exec chmod +x {} +
chmod +x "$DOTFILES_DIR/install.sh" "$DOTFILES_DIR/backup.sh" 2>/dev/null || true

echo "==> [9/9] Đã hoàn tất Full Backup 100%!"

# 10. Sao lưu cấu hình Ly Display Manager (/etc/ly)
echo "==> [10/10] Sao lưu cấu hình Ly Display Manager (/etc/ly)..."
mkdir -p "$DOTFILES_DIR/system/etc/ly"
if [ -d "/etc/ly" ]; then
    cp -afr /etc/ly/* "$DOTFILES_DIR/system/etc/ly/" 2>/dev/null || true
fi
