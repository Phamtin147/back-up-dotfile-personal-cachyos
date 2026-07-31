#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_TARGET="$HOME"
CONFIG_TARGET="$HOME/.config"
DRY_RUN=false
WITH_SYSTEM=false

print_help() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run        Chỉ in ra các thao tác, không thực hiện
  --with-system    Cài cả cấu hình hệ thống (/etc, cần sudo)
  -h, --help       Hiển thị trợ giúp
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --with-system) WITH_SYSTEM=true ;;
        -h|--help) print_help; exit 0 ;;
        *) echo "Lỗi: tham số không hợp lệ: $arg"; print_help; exit 1 ;;
    esac
done

link_file() {
    local src="$1" dest="$2" cmd_prefix="$3"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$(readlink -f "$src")" = "$(readlink -f "$dest")" ]; then
            echo "  ~ Bỏ qua (đã đúng): $dest"
            return
        fi
        local backup="${dest}.bak"
        echo "  ~ Backup: $dest -> $backup"
        $DRY_RUN || $cmd_prefix mv "$dest" "$backup"
    fi
    echo "  + Link: $src -> $dest"
    $DRY_RUN || $cmd_prefix ln -s "$src" "$dest"
}

install_home() {
    echo "==> Cài đặt các dotfile trong home ($HOME)"
    shopt -s dotglob nullglob
    for entry in "$DOTFILES_DIR"/home/*; do
        [ -e "$entry" ] || continue
        local name
        name="$(basename "$entry")"
        case "$name" in
            .|..|apply-wallpaper-patch.sh) continue ;;
        esac
        link_file "$entry" "$HOME_TARGET/$name" ""
    done
    shopt -u dotglob nullglob
}

install_config() {
    echo "==> Cài đặt ~/.config"
    mkdir -p "$CONFIG_TARGET"
    for entry in "$DOTFILES_DIR"/config/*; do
        [ -e "$entry" ] || continue
        link_file "$entry" "$CONFIG_TARGET/$(basename "$entry")" ""
    done
}

install_system() {
    echo "==> Cài đặt cấu hình hệ thống (/etc)"
    if ! $DRY_RUN; then
        sudo -v || { echo "Lỗi: cần quyền sudo"; exit 1; }
    fi
    local etc_dir="$DOTFILES_DIR/system/etc"
    [ -d "$etc_dir" ] || return
    while IFS= read -r -d '' f; do
        local rel dest
        rel="${f#"$etc_dir"/}"
        dest="/etc/$rel"
        sudo mkdir -p "$(dirname "$dest")"
        link_file "$f" "$dest" "sudo"
    done < <(find "$etc_dir" -type f -print0)
}

install_home
install_config
if $WITH_SYSTEM; then
    install_system
else
    echo "==> Bỏ qua /etc (dùng --with-system để cài, cần sudo)"
fi

echo ""
echo "Hoàn tất! Khởi động lại shell (exec zsh) để áp dụng."
echo "Lưu ý: Một số config cần phần mềm tương ứng (niri, yazi, btop...)."
