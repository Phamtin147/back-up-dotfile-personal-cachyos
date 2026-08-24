#!/usr/bin/env bash
# ==============================================================================
# Script Cài đặt & Khôi phục 100% Dotfiles & Môi trường CachyOS
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_TARGET="$HOME"
CONFIG_TARGET="$HOME/.config"
DRY_RUN=false
WITH_SYSTEM=false
WITH_PACKAGES=false

print_help() {
    cat <<'HELP'
Sử dụng: ./install.sh [options]

Tùy chọn:
  --with-packages, -p  Tự động cài đặt đầy đủ package (Pacman + AUR + Flatpak)
  --with-system, -s    Cài đặt cả cấu hình hệ thống (/etc, cần quyền sudo)
  --dry-run, -d        Chỉ in ra thao tác mô phỏng, không thực hiện thay đổi
  -h, --help           Hiển thị hướng dẫn sử dụng

Ví dụ:
  ./install.sh                  # Khôi phục toàn bộ dotfiles, fonts, icons, wallpapers, scripts, noctalia UI
  ./install.sh --with-packages  # Khôi phục và cài đặt luôn toàn bộ phần mềm trên máy mới
  ./install.sh --all            # Cài packages + khôi phục toàn bộ + cấu hình hệ thống
HELP
}

for arg in "$@"; do
    case "$arg" in
        --dry-run|-d) DRY_RUN=true ;;
        --with-system|-s) WITH_SYSTEM=true ;;
        --with-packages|-p) WITH_PACKAGES=true ;;
        --all|-a) WITH_PACKAGES=true; WITH_SYSTEM=true ;;
        -h|--help) print_help; exit 0 ;;
        *) echo "Lỗi: tham số không hợp lệ: $arg"; print_help; exit 1 ;;
    esac
done

link_entry() {
    local src="$1" dest="$2" cmd_prefix="${3:-}"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$(readlink -f "$src")" = "$(readlink -f "$dest")" ]; then
            echo "  ~ [Đã liên kết]: $dest"
            return
        fi
        local backup="${dest}.bak"
        echo "  ~ [Backup cũ]: $dest -> $backup"
        $DRY_RUN || $cmd_prefix mv "$dest" "$backup"
    fi
    echo "  + [Link]: $src -> $dest"
    $DRY_RUN || $cmd_prefix ln -s "$src" "$dest"
}

copy_entry() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -d "$src" ]; then
        echo "  + [Copy dir]: $src -> $dest"
        $DRY_RUN || rsync -a "$src/" "$dest/"
    else
        echo "  + [Copy file]: $src -> $dest"
        $DRY_RUN || cp -af "$src" "$dest"
    fi
}

install_packages() {
    echo "==> [1/10] Cài đặt các gói phần mềm..."
    if $DRY_RUN; then
        echo "  (Mô phỏng) Chạy $DOTFILES_DIR/system/packages/install-packages.sh"
    else
        bash "$DOTFILES_DIR/system/packages/install-packages.sh"
    fi
}

install_home() {
    echo "==> [2/10] Cài đặt các dotfile trong $HOME..."
    shopt -s dotglob nullglob
    for entry in "$DOTFILES_DIR"/home/*; do
        [ -e "$entry" ] || continue
        local name
        name="$(basename "$entry")"
        case "$name" in
            .|..|apply-wallpaper-patch.sh|fix-usb-optional.sh) continue ;;
        esac
        link_entry "$entry" "$HOME_TARGET/$name"
    done
    shopt -u dotglob nullglob
}

install_config() {
    echo "==> [3/10] Cài đặt cấu hình vào $CONFIG_TARGET..."
    mkdir -p "$CONFIG_TARGET"
    shopt -s nullglob
    for entry in "$DOTFILES_DIR"/config/*; do
        [ -e "$entry" ] || continue
        local name
        name="$(basename "$entry")"
        link_entry "$entry" "$CONFIG_TARGET/$name"
    done
    shopt -u nullglob

    if [ -f "$DOTFILES_DIR/vscode-custom.css" ]; then
        link_entry "$DOTFILES_DIR/vscode-custom.css" "$CONFIG_TARGET/vscode-custom.css"
    fi
}

install_state() {
    echo "==> [4/10] Cài đặt Noctalia Runtime & State vào $HOME/.local/state/noctalia..."
    if [ -d "$DOTFILES_DIR/state/noctalia" ]; then
        mkdir -p "$HOME/.local/state/noctalia"
        copy_entry "$DOTFILES_DIR/state/noctalia" "$HOME/.local/state/noctalia"
    fi
}

install_bin() {
    echo "==> [5/10] Cài đặt toàn bộ scripts vào $HOME/.local/bin..."
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    
    while IFS= read -r -d '' script; do
        chmod +x "$script" 2>/dev/null || true
        local sname
        sname="$(basename "$script")"
        link_entry "$script" "$bin_dir/$sname"
    done < <(find "$DOTFILES_DIR/scripts" -type f -print0)
}

install_assets() {
    echo "==> [6/10] Cài đặt Fonts, Icons, Themes, Desktop files..."
    
    # Fonts
    if [ -d "$DOTFILES_DIR/fonts" ]; then
        local font_dir="$HOME/.local/share/fonts"
        mkdir -p "$font_dir"
        copy_entry "$DOTFILES_DIR/fonts" "$font_dir"
        if ! $DRY_RUN && command -v fc-cache >/dev/null 2>&1; then
            echo "  ~ Đang cập nhật font cache (fc-cache)..."
            fc-cache -f "$font_dir" >/dev/null 2>&1 || true
        fi
    fi

    # Icons & Cursors
    if [ -d "$DOTFILES_DIR/icons" ]; then
        mkdir -p "$HOME/.icons" "$HOME/.local/share/icons"
        copy_entry "$DOTFILES_DIR/icons" "$HOME/.icons"
        copy_entry "$DOTFILES_DIR/icons" "$HOME/.local/share/icons"
    fi

    # Themes
    if [ -d "$DOTFILES_DIR/themes" ]; then
        mkdir -p "$HOME/.themes"
        copy_entry "$DOTFILES_DIR/themes" "$HOME/.themes"
    fi

    # Desktop entries
    if [ -d "$DOTFILES_DIR/desktop" ]; then
        mkdir -p "$HOME/.local/share/applications"
        copy_entry "$DOTFILES_DIR/desktop" "$HOME/.local/share/applications"
        if ! $DRY_RUN && command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
        fi
    fi
}

install_wallpapers() {
    echo "==> [7/10] Cài đặt kho hình nền vào $HOME/Pictures/Wallpapers..."
    if [ -d "$DOTFILES_DIR/wallpapers" ]; then
        mkdir -p "$HOME/Pictures/Wallpapers"
        copy_entry "$DOTFILES_DIR/wallpapers" "$HOME/Pictures/Wallpapers"
    fi
}

install_shaders() {
    echo "==> [8/10] Cài đặt Shaders vào $HOME/shaders..."
    if [ -d "$DOTFILES_DIR/shaders" ]; then
        mkdir -p "$HOME/shaders"
        copy_entry "$DOTFILES_DIR/shaders" "$HOME/shaders"
    fi
}

install_dconf() {
    echo "==> [9/10] Khôi phục thiết lập dconf & User Services..."
    local dconf_file="$DOTFILES_DIR/system/dconf/dconf-settings.ini"
    if [ -f "$dconf_file" ] && command -v dconf >/dev/null 2>&1; then
        if ! $DRY_RUN; then
            dconf load / < "$dconf_file" || true
            echo "  ~ Đã nạp thành công dconf settings!"
        else
            echo "  (Mô phỏng) dconf load / < $dconf_file"
        fi
    fi

    # Kích hoạt systemd user services
    if ! $DRY_RUN && command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        if [ -f "$HOME/.config/systemd/user/hyprlock-cava.service" ]; then
            systemctl --user enable hyprlock-cava.service 2>/dev/null || true
        fi
    fi
}

install_system() {
    echo "==> [10/10] Cài đặt cấu hình hệ thống (/etc)..."
    if ! $DRY_RUN; then
        sudo -v || { echo "Lỗi: Cần quyền sudo để cài cấu hình hệ thống"; exit 1; }
    fi
    local etc_dir="$DOTFILES_DIR/system/etc"
    [ -d "$etc_dir" ] || return
    while IFS= read -r -d '' f; do
        local rel dest
        rel="${f#"$etc_dir"/}"
        dest="/etc/$rel"
        sudo mkdir -p "$(dirname "$dest")"
        link_entry "$f" "$dest" "sudo"
    done < <(find "$etc_dir" -type f -print0)
}

# --- THỰC HIỆN CÁC BƯỚC ---
if $WITH_PACKAGES; then
    install_packages
fi

install_home
install_config
install_state
install_bin
install_assets
install_wallpapers
install_shaders
install_dconf

if $WITH_SYSTEM; then
    install_system
else
    echo "==> Bỏ qua /etc (dùng --with-system nếu muốn cài đặt /etc, cần sudo)"
fi

echo ""
echo "🎉 HOÀN TẤT! Toàn bộ hệ thống & giao diện Noctalia đã được khôi phục 100% y đúc."
echo "👉 Khởi động lại session hoặc gõ 'exec zsh' để áp dụng!"
