{ config }:

''
# Left prompt
if [[ $UID == 0 || $EUID == 0 ]]; then
  PROMPT_BASE="%F{1}%3~ %(1j.%j .)#%f"
else
  PROMPT_BASE="%F{3}%3~ %(1j.%F{1}%j .)%F{4}$%f"
fi

function set-prompt {
  case $KEYMAP in
    (vicmd)       VI_MODE="%F{12}[N]" ;;
    (main|viins)  VI_MODE="%F{8}[I]" ;;
    (*)           VI_MODE="[ ]" ;;
  esac

  PROMPT=" $VI_MODE $PROMPT_BASE "
}

function zle-keymap-select zle-line-init {
  set-prompt
  zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select

# Right prompt

autoload -Uz vcs_info
zstyle ":vcs_info:git*" formats "%F{5}%s%f:%F{2}%b%f"
precmd() {
  vcs_info
  echo -n -e "\033]0;$USER@$HOST: ''${PWD/$HOME/~}\007"
}
RPROMPT=" ''${vcs_info_msg_0_} %?"

setopt GLOBSTARSHORT
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt PROMPT_SUBST

bindkey -s "^Z" "fg\n"
bindkey -s "^N" "cps\n"

${if config.base.keyboard.layout == "hallmack" then ''
# swap h g
bindkey -M vicmd -r "^H"
bindkey -M vicmd -r "h"
bindkey -M vicmd "g" vi-backward-char
bindkey -M vicmd -r "G"

# swap j a
bindkey -M vicmd "a" down-line-or-history
bindkey -M vicmd "A" vi-join
bindkey -M vicmd "J" vi-open-line-above
bindkey -M vicmd "j" vi-open-line-below

# swap k e
bindkey -M vicmd "e" up-line-or-history
bindkey -M vicmd -r "E"
bindkey -M vicmd "k" vi-add-next
bindkey -M vicmd "K" vi-add-eol

# swap l o
bindkey -M vicmd "o" vi-forward-char
bindkey -M visual "o" vi-forward-char
bindkey -M vicmd -r "O"
bindkey -M vicmd "l" vi-forward-word-end
bindkey -M vicmd "L" vi-forward-blank-word-end
'' else ""}

zstyle ":completion:*" matcher-list "m:{a-z}={A-Za-z}"
''
