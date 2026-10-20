# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source $HOME/cachyos-config.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Put ~/.local/bin at the front of PATH
export PATH="/home/amtia/.local/bin:$PATH"
alias wifi-menu="/home/amtia/.local/bin/wifi-menu"

# bun completions
[ -s "/home/amtia/.bun/_bun" ] && source "/home/amtia/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH=$HOME/.npm-global/bin:$PATH


# Load Angular CLI autocompletion.
source <(ng completion script)
export PATH="$PATH:$HOME/flutter/bin"
export NODE_TLS_REJECT_UNAUTHORIZED=0

export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
