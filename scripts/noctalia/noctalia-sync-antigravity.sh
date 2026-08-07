#!/usr/bin/env bash
# noctalia-sync-antigravity.sh
# Đồng bộ màu Noctalia hiện tại vào settings.json của Antigravity
set -euo pipefail

# Tìm theme file từ .antigravity hoặc .vscode
THEME_FILE=""
for candidate in \
    "$HOME/.antigravity/extensions/noctalia.noctaliatheme-0.0.5-universal/themes/NoctaliaTheme-color-theme.json" \
    "$HOME/.vscode/extensions/noctalia.noctaliatheme-0.0.5/themes/NoctaliaTheme-color-theme.json"; do
    if [ -f "$candidate" ]; then
        THEME_FILE="$candidate"
        break
    fi
done

if [ -z "$THEME_FILE" ]; then
    # Thử tìm theo wildcard
    THEME_FILE=$(find "$HOME/.antigravity/extensions" "$HOME/.vscode/extensions" -maxdepth 4 -name "NoctaliaTheme-color-theme.json" 2>/dev/null | head -n 1 || true)
fi

if [ -z "$THEME_FILE" ] || [ ! -f "$THEME_FILE" ]; then
    echo "LỖI: Không tìm thấy theme Noctalia tại $THEME_FILE"
    exit 1
fi

SETTINGS_TARGETS=()
for target in "$HOME/.config/Antigravity/User/settings.json" "$HOME/.config/Antigravity IDE/User/settings.json"; do
    if [ -f "$target" ]; then
        SETTINGS_TARGETS+=("$target")
    fi
done

if [ ${#SETTINGS_TARGETS[@]} -eq 0 ]; then
    echo "Không tìm thấy file settings.json nào của Antigravity"
    exit 0
fi

python3 - "$THEME_FILE" "${SETTINGS_TARGETS[@]}" <<'EOF'
import json, sys

theme_path = sys.argv[1]
settings_paths = sys.argv[2:]

try:
    theme = json.load(open(theme_path))
except Exception as e:
    print(f"Lỗi đọc theme file {theme_path}: {e}", file=sys.stderr)
    sys.exit(1)

colors = theme.get("colors", {})
token_rules = []
for item in theme.get("tokenColors", []):
    scope = item.get("scope")
    fg = item.get("settings", {}).get("foreground")
    if scope and fg:
        token_rules.append({"scope": scope, "settings": {"foreground": fg}})

sem = theme.get("semanticTokenColors", {})

for settings_path in settings_paths:
    try:
        raw = open(settings_path, "r", encoding="utf-8").read()
        # Clean trailing commas if any
        cleaned_lines = []
        for line in raw.splitlines():
            # Basic cleanup for json trailing commas before close brace/bracket
            cleaned_lines.append(line)
        cleaned_raw = "\n".join(cleaned_lines)
        
        # Parse using standard json or json5 regex fallback if needed
        import re
        cleaned_raw = re.sub(r',(\s*[\}\]])', r'\1', cleaned_raw)
        settings = json.loads(cleaned_raw)

        settings["workbench.colorTheme"] = "NoctaliaTheme"
        settings["workbench.colorCustomizations"] = colors
        settings["editor.tokenColorCustomizations"] = {"textMateRules": token_rules}
        if sem:
            settings["editor.semanticTokenColorCustomizations"] = {"rules": sem}

        with open(settings_path, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=4, ensure_ascii=False)

        print(f"  OK: {settings_path}")
        print(f"      colors={len(colors)}, tokenRules={len(token_rules)}")
    except Exception as e:
        print(f"  LỖI cập nhật {settings_path}: {e}", file=sys.stderr)

EOF

echo "Xong! Đã đồng bộ màu cho Antigravity."

