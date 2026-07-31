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
  RPROMPT=' ''${vcs_info_msg_0_} %?'

  setopt GLOBSTARSHORT
  setopt HIST_IGNORE_ALL_DUPS
  setopt HIST_REDUCE_BLANKS
  setopt INC_APPEND_HISTORY
  setopt PROMPT_SUBST

  bindkey -s "^Z" "fg\n"
  bindkey -s "^N" "cps\n"

  # WORDCHARS is trimmed inside the widget, not globally: dropping - . = /
  # walks a path or a flag piece by piece, while ^W and the vi motions keep
  # the default.
  function ctrl-forward-word ctrl-backward-word {
    local WORDCHARS='*?_[]~&;!#$%^(){}<>'
    zle ''${WIDGET#ctrl-}
  }
  zle -N ctrl-forward-word
  zle -N ctrl-backward-word

  for keymap in viins vicmd; do
    bindkey -M $keymap "^[[1;5C" ctrl-forward-word
    bindkey -M $keymap "^[[1;5D" ctrl-backward-word
  done

  # Bracket and quote text objects — ci[, ca(, di" and friends. These need no
  # operator widget, unlike surround below: in viopp the leading i/a is a
  # prefix that is not itself a binding, so zsh waits for the second key
  # instead of timing out.
  autoload -Uz select-bracketed select-quoted
  zle -N select-bracketed
  zle -N select-quoted
  for keymap in visual viopp; do
    for pair in {a,i}{'(',')','[',']','{','}','<','>',b,B}; do
      bindkey -M $keymap $pair select-bracketed
    done
    for pair in {a,i}{\',\",\`}; do
      bindkey -M $keymap $pair select-quoted
    done
  done

  # vim-surround, bound to the operator key alone rather than to cs/ds/ys:
  # c, d and y are complete bindings as well as prefixes, so zsh would wait
  # only KEYTIMEOUT — 1, to keep Escape instant — for the second key before
  # firing the bare operator. `read -k` has no such timeout.
  #
  # The widget names must match surround's own change-*/delete-*/add-* dispatch
  # on $WIDGET, and surround must be called as a function: for a nested `zle`
  # call zsh leaves $WIDGET at the outer widget's name.
  autoload -Uz surround

  function _surround-operator {
    local key
    read -k 1 key
    if [[ $key == s ]]; then
      surround
    else
      zle -U "$key"
      zle "$1"
    fi
  }
  function change-surround-or-vi-change { _surround-operator .vi-change }
  function delete-surround-or-vi-delete { _surround-operator .vi-delete }
  function add-surround-or-vi-yank { _surround-operator .vi-yank }
  zle -N change-surround-or-vi-change
  zle -N delete-surround-or-vi-delete
  zle -N add-surround-or-vi-yank

  bindkey -M vicmd "c" change-surround-or-vi-change
  bindkey -M vicmd "d" delete-surround-or-vi-delete
  bindkey -M vicmd "y" add-surround-or-vi-yank

  zle -N add-surround surround
  bindkey -M visual "S" add-surround

  ${
    if config.base.keyboard.layout == "hallmack" then
      ''
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
      ''
    else
      ""
  }

  zstyle ":completion:*" matcher-list "m:{a-z}={A-Za-z}"
''
