#!/usr/bin/env python3
# Finds all installed Noctalia theme extensions for VSCode/VSCodium.

import sys
from pathlib import Path


def find_all_noctalia_themes(extensions_dir: Path, prefix: str) -> list[str]:
    # Bail early if the extensions directory doesn't exist
    if not extensions_dir.is_dir():
        return []
    # Collect all directories matching the extension prefix
    candidates = [d for d in extensions_dir.iterdir() if d.is_dir() and d.name.startswith(prefix)]
    # Return theme file paths for all matching extensions
    return [str(d / "themes" / "NoctaliaTheme-color-theme.json") for d in candidates]


if __name__ == "__main__":
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    prefix = "noctalia.noctaliatheme-"
    
    found_any = False
    for arg in dirs:
        extensions_dir = Path(arg).expanduser()
        results = find_all_noctalia_themes(extensions_dir, prefix)
        if results:
            for path in results:
                print(path)
                found_any = True
                
    if not found_any:
        sys.exit(1)