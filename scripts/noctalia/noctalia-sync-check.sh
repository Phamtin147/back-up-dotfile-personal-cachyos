#!/usr/bin/env bash
# Usage: noctalia-sync-check.sh [apply]
set -euo pipefail

SHELL_DIR="${HOME}/.config/quickshell/noctalia-shell"
TP_SCRIPT="${SHELL_DIR}/Scripts/python/src/theming/template-processor.py"
GTK_REFRESH="${SHELL_DIR}/Scripts/python/src/theming/gtk-refresh.py"
COLORS_JSON="${HOME}/.config/noctalia/colors.json"
ZEN_PROFILE=$(grep -h "Default=" ~/.config/zen/installs.ini 2>/dev/null | head -1 | cut -d= -f2)

check() {
    echo "==> [GTK4] noctalia.css:"
    [ -f "${HOME}/.config/gtk-4.0/noctalia.css" ] && echo "    OK  gtk-4.0/noctalia.css" || echo "    MISSING gtk-4.0/noctalia.css"
    [ -f "${HOME}/.config/gtk-3.0/noctalia.css" ] && echo "    OK  gtk-3.0/noctalia.css" || echo "    MISSING gtk-3.0/noctalia.css"

    echo "==> [GTK4] @import trong gtk.css:"
    grep -q "noctalia.css" "${HOME}/.config/gtk-4.0/gtk.css" && echo "    OK  gtk-4.0/gtk.css imports noctalia.css" || echo "    MISSING import trong gtk-4.0/gtk.css"
    grep -q "noctalia.css" "${HOME}/.config/gtk-3.0/gtk.css" && echo "    OK  gtk-3.0/gtk.css imports noctalia.css" || echo "    MISSING import trong gtk-3.0/gtk.css"

    echo "==> [gsettings] Dark mode:"
    CS=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "")
    echo "    color-scheme = $CS"

    echo "==> [Niri] noctalia.kdl:"
    [ -f "${HOME}/.config/niri/noctalia.kdl" ] && echo "    OK  niri/noctalia.kdl (active-color: $(grep -m1 'active-color' "${HOME}/.config/niri/noctalia.kdl" | tr -d ' "'))" || echo "    MISSING niri/noctalia.kdl"

    echo "==> [Zen Browser] profile: ${ZEN_PROFILE:-chưa xác định}"
    if [ -n "${ZEN_PROFILE}" ] && [ -d "${HOME}/.config/zen/${ZEN_PROFILE}" ]; then
        CHROME="${HOME}/.config/zen/${ZEN_PROFILE}/chrome"
        grep -q "zen-userChrome.css" "${CHROME}/userChrome.css" 2>/dev/null && echo "    OK  userChrome.css -> noctalia zen CSS" || echo "    MISSING import trong userChrome.css"
        grep -q "zen-userContent.css" "${CHROME}/userContent.css" 2>/dev/null && echo "    OK  userContent.css -> noctalia zen CSS" || echo "    MISSING import trong userContent.css"
        grep -q 'legacyUserProfileCustomizations.stylesheets", true' "${HOME}/.config/zen/${ZEN_PROFILE}/prefs.js" 2>/dev/null \
            && echo "    OK  toolkit.legacyUserProfileCustomizations.stylesheets = true" \
            || echo "    NOTE: flag legacyUserProfileCustomizations chưa bật (cần Zen khởi động để ghi)"
    else
        echo "    NOTE: không tìm thấy profile (kiểm tra ~/.config/zen/installs.ini)"
    fi

    echo "==> [Zen Browser] noctalia zen CSS:"
    [ -f "${HOME}/.cache/noctalia/zen-browser/zen-userChrome.css" ] && echo "    OK  ~/.cache/noctalia/zen-browser/zen-userChrome.css" || echo "    MISSING zen-userChrome.css"

    echo "==> [Đồng bộ màu hiện tại]:"
    echo "    Primary (GTK) : $(grep -m1 'accent_color' "${HOME}/.config/gtk-4.0/noctalia.css" 2>/dev/null | awk '{print $3}')"
    echo "    Primary (Zen) : $(grep -m1 -- '--primary:' "${HOME}/.cache/noctalia/zen-browser/zen-userChrome.css" 2>/dev/null | awk '{print $2}')"
    echo "    Primary (Niri): $(grep -m1 'active-color' "${HOME}/.config/niri/noctalia.kdl" 2>/dev/null | grep -oE '#[0-9a-fA-F]+' | head -1)"
}

apply() {
    echo "==> Sinh lại GTK noctalia.css từ màu hiện tại (${COLORS_JSON})..."
    python3 -c "
import json
c = json.load(open('${COLORS_JSON}'))
json.dump({'dark': c}, open('/tmp/noctalia-current-scheme.json','w'), indent=2)
"
    cat > /tmp/noctalia-gtk.toml <<EOF
[config]

[templates.gtk_0]
input_path = "${SHELL_DIR}/Assets/Templates/gtk3.css"
output_path = "${HOME}/.config/gtk-3.0/noctalia.css"

[templates.gtk_1]
input_path = "${SHELL_DIR}/Assets/Templates/gtk4.css"
output_path = "${HOME}/.config/gtk-4.0/noctalia.css"
EOF

    (cd "$(dirname "${TP_SCRIPT}")" && python3 "${TP_SCRIPT}" --scheme /tmp/noctalia-current-scheme.json --config /tmp/noctalia-gtk.toml --mode dark --default-mode dark)

    echo "==> Cập nhật @import + gsettings..."
    python3 "${GTK_REFRESH}" dark

    echo "==> Done. Chạy lại không đối số để verify."
}

case "${1:-}" in
    apply) apply ;;
    *)     check ;;
esac
