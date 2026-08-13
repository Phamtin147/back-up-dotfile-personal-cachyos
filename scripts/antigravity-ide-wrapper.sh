1
#!/bin/bash

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

if [[ -f $XDG_CONFIG_HOME/antigravity-ide-flags.conf ]]; then
    ANTIGRAVITY_IDE_USER_FLAGS="$(sed 's/#.*//' $XDG_CONFIG_HOME/antigravity-ide-flags.conf | tr '\n' ' ')"
fi

export NODE_OPTIONS="--require=$HOME/.config/antigravity-css-preload.js"

exec /opt/antigravity-ide/bin/antigravity-ide "$@" $ANTIGRAVITY_IDE_USER_FLAGS
