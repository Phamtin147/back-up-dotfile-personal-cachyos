#!/usr/bin/env bash
# noctalia-sync-antigravity.sh
# Đồng bộ màu Noctalia hiện tại vào settings.json của Antigravity (cả 2 bản)
# Cách dùng: sau mỗi lần Noctalia đổi màu, chạy lệnh này.
set -euo pipefail

THEME_FILE="$HOME/.vscode/extensions/noctalia.noctaliatheme-0.0.5/themes/NoctaliaTheme-color-theme.json"
SETTINGS_AG="$HOME/.config/Antigravity/User/settings.json"
SETTINGS_AGIDE="$HOME/.config/Antigravity IDE/User/settings.json"

if [ ! -f "$THEME_FILE" ]; then
    echo "LỖI: Không tìm thấy theme Noctalia tại $THEME_FILE"
    echo "Bạn cần cài extension noctalia.noctaliatheme vào VSCode trước."
    exit 1
fi

python3 - "$THEME_FILE" "$SETTINGS_AG" <<'EOF'
import json, sys

theme_path, settings_path = sys.argv[1], sys.argv[2]

theme = json.load(open(theme_path))

# settings.json của Antigravity có thể chứa trailing comma -> làm sạch trước khi parse
raw = open(settings_path).read()
raw = raw.replace(',\n}', '\n}')
settings = json.loads(raw)

# Giữ nguyên theme ID cho trường hợp extension được load
settings["workbench.colorTheme"] = "NoctaliaTheme"
# Inject toàn bộ màu UI
settings["workbench.colorCustomizations"] = theme.get("colors", {})

# Inject màu syntax (tokenColors)
token_rules = []
for item in theme.get("tokenColors", []):
    scope = item.get("scope")
    fg = item.get("settings", {}).get("foreground")
    if scope and fg:
        token_rules.append({"scope": scope, "settings": {"foreground": fg}})
settings["editor.tokenColorCustomizations"] = {"textMateRules": token_rules}

# Inject semantic tokens
sem = theme.get("semanticTokenColors", {})
if sem:
    settings["editor.semanticTokenColorCustomizations"] = {"rules": sem}

json.dump(settings, open(settings_path, "w"), indent=4)
print(f"  OK: {settings_path}")
print(f"      colors={len(theme.get('colors', {}))}, tokenRules={len(token_rules)}")
EOF

for s in "$SETTINGS_AG" "$SETTINGS_AGIDE"; do
    if [ -f "$s" ]; then
        echo "  OK: $s"
    fi
done

echo "Xong! Mở lại Antigravity (Reload Window) để thấy màu mới."
