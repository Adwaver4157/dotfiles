# ============================================================================
# Zsh Configuration  (merged: kami base, adapted to pixi + portable paths)
# Machine-specific lines (anyenv, API keys, host paths) go in ~/.zshrc.local
# ============================================================================

# ----------------------------------------------------------------------------
# History
# ----------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=20000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# ----------------------------------------------------------------------------
# Key Bindings
# ----------------------------------------------------------------------------
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
bindkey "^[[1;3C" forward-word     # Alt+Right
bindkey "^[[1;3D" backward-word    # Alt+Left
bindkey "^[^[[C" forward-word
bindkey "^[^[[D" backward-word

# ----------------------------------------------------------------------------
# Tmux Integration
# ----------------------------------------------------------------------------
function precmd() {
  if [ ! -z $TMUX ]; then
    tmux refresh-client -S
  fi
}

# ----------------------------------------------------------------------------
# SSH Agent Forwarding Fix (for tmux)
# ----------------------------------------------------------------------------
if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock" ]; then
    ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock" 2>/dev/null
fi
export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"

# ----------------------------------------------------------------------------
# Nested Neovim Protection (open files in the parent nvim from :terminal)
# ----------------------------------------------------------------------------
if [[ -n "$NVIM" ]]; then
  nvim() {
    local mode='split'
    if [[ "$1" == "-e" || "$1" == "--edit" ]]; then
      mode='edit'; shift
    fi
    [[ $# -eq 0 ]] && return 0
    local f abs
    for f in "$@"; do
      case "$f" in
        /*) abs="$f" ;;
        *)  abs="$PWD/$f" ;;
      esac
      command nvim --server "$NVIM" --remote-send \
        "<Cmd>lua _G.OpenFromTerm([==[${abs}]==], [==[${mode}]==])<CR>" 2>/dev/null
    done
  }
fi

# ----------------------------------------------------------------------------
# PATH  (portable — no hard-coded usernames)
# ----------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
# Homebrew (transition: keep brew tools available; pixi prepended after so it wins)
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="$HOME/.pixi/bin:$PATH"
[ -d /usr/local/go/bin ] && export PATH="$PATH:/usr/local/go/bin"

# ----------------------------------------------------------------------------
# Tool init / completions  (all guarded — no-op if the tool is absent)
# ----------------------------------------------------------------------------
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
else
  # Readable colored fallback when starship isn't installed
  autoload -Uz colors add-zsh-hook vcs_info && colors
  setopt PROMPT_SUBST
  zstyle ':vcs_info:git:*' formats ' %F{yellow}%b%f'
  add-zsh-hook precmd vcs_info
  PROMPT='%F{green}%n@%m%f %F{cyan}%~%f${vcs_info_msg_0_} %(?.%F{green}.%F{red})%#%f '
fi
command -v zoxide   &>/dev/null && eval "$(zoxide init zsh)"
command -v fzf      &>/dev/null && source <(fzf --zsh) 2>/dev/null
command -v direnv   &>/dev/null && eval "$(direnv hook zsh)"   # standalone direnv (brew/pixi), not asdf

# Optional brew completion bundles (present on a brew machine, skipped otherwise)
for _f in \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [ -f "$_f" ] && source "$_f"
done
unset _f
[ -d /opt/homebrew/share/zsh-completions ]      && FPATH=/opt/homebrew/share/zsh-completions:$FPATH
[ -d /opt/homebrew/share/zsh/site-functions ]   && FPATH=/opt/homebrew/share/zsh/site-functions:$FPATH

autoload -Uz compinit && compinit
command -v pixi &>/dev/null && eval "$(pixi completion --shell zsh)"

# ----------------------------------------------------------------------------
# Claude Code: enable experimental Agent Teams
# ----------------------------------------------------------------------------
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# ----------------------------------------------------------------------------
# Modular configs (ssh backoff guard + vdd, etc.)
# ----------------------------------------------------------------------------
for _zf in ~/.config/zsh/*.zsh(N); do source "$_zf"; done; unset _zf

# ----------------------------------------------------------------------------
# Machine-local config (API keys, anyenv, host-specific paths)
# ----------------------------------------------------------------------------
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# ============================================================================
# Aliases
# ============================================================================
command -v eza &>/dev/null && alias ls='eza'
command -v bat &>/dev/null && alias cat='bat'
alias vi='nvim'
alias vim='nvim'
alias k='kubectl'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias dot='cd ~/dotfiles'
alias cls='clear'

# ============================================================================
# Functions
# ============================================================================

# Create a directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Extract most archive formats into a same-named directory
extract() {
  if [ -z "$1" ]; then echo "Usage: extract <archive-file>"; return 1; fi
  local archive="$1" dirname="${1%.*}"
  case "$archive" in
    *.tar.gz|*.tar.bz2|*.tar.xz) dirname="${archive%.tar.*}" ;;
  esac
  mkdir -p "$dirname"
  case "$1" in
    *.tar.gz|*.tgz)  tar xzf "$archive" -C "$dirname" ;;
    *.tar.bz2|*.tbz) tar xjf "$archive" -C "$dirname" ;;
    *.tar.xz)        tar xJf "$archive" -C "$dirname" ;;
    *.tar)           tar xf  "$archive" -C "$dirname" ;;
    *.zip)           unzip -q "$archive" -d "$dirname" ;;
    *.gz)            gunzip -c "$archive" > "$dirname/${archive%.gz}" ;;
    *.bz2)           bunzip2 -c "$archive" > "$dirname/${archive%.bz2}" ;;
    *.rar)           unrar x "$archive" "$dirname/" ;;
    *.7z)            7z x "$archive" -o"$dirname" ;;
    *)               echo "Unknown archive format: $1"; rmdir "$dirname" 2>/dev/null; return 1 ;;
  esac
  echo "Extracted to: $dirname/"
}

# tmux project switcher: pick a project dir with fzf and launch tmux-dev
ts() {
  local dir
  dir=$(find ~/workspace ~/projects ~/work ~/dotfiles -maxdepth 2 -type d 2>/dev/null | fzf) || return
  tmux-dev "$dir"
}

# Check / free a TCP port.   port 8080   |   port -k 8080 (kill listener)
port() {
  if [ "$1" = "-k" ]; then
    local pids; pids=$(lsof -ti:"${2:?usage: port -k <PORT>}" 2>/dev/null)
    if [ -n "$pids" ]; then printf '%s\n' "$pids" | xargs kill && echo "killed :$2"; else echo ":$2 — nothing listening"; fi
    return
  fi
  lsof -nP -iTCP:"${1:?usage: port <PORT> | port -k <PORT>}" -sTCP:LISTEN || echo ":$1 is free"
}
