# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # If you're using macOS, you'll want this enabled
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export BS_DIR="$HOME/Dev/bs"
source "$BS_DIR/bs.sh"

# Switch bs to current directory (run from a bs branch space) or back to main
bs-dev() {
  if [[ "$1" == "reset" ]]; then
    export BS_DIR="$HOME/Dev/bs"
  else
    export BS_DIR="$(pwd)"
  fi
  source "$BS_DIR/bs.sh"
  echo "BS_DIR=$BS_DIR"
}

# Exports
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export BAT_THEME="Visual Studio Dark+"

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1
zinit light romkatv/powerlevel10k

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Load completions
autoload -Uz compinit && compinit
[ -s "/Users/ben/.bun/_bun" ] && source "/Users/ben/.bun/_bun"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Keybindings
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias ls='ls --color'
alias c='clear'

alias gad='git add .'
alias gcm='git commit --no-verify -m'
alias gp='git push'

alias devfilter="echo '-/(aptrinsic|datadoghq|renewtoken|intercom|segment)/ -is:service-worker-initiated' | pbcopy && echo 'Filter copied to clipboard!'"

alias bathelp='bat --plain --language=help'
help() {
    "$@" --help 2>&1 | bathelp
}
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# opencode
export PATH=/Users/ben/.opencode/bin:$PATH
export PATH="$HOME/.local/bin:$PATH"

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

# Create worktree, tracking remote branch if it exists, otherwise new branch off main
wtc() {
  if [[ -z "$1" ]]; then
    echo "Usage: wtc <branch-name>" >&2
    return 1
  fi
  git fetch origin "$1" 2>/dev/null
  if git rev-parse --verify "origin/$1" &>/dev/null; then
    echo "Remote branch origin/$1 found, tracking it"
    wt switch "$1"
  else
    wt switch --create "$1"
  fi
}

# Remove all worktrees whose branches are integrated into main
wtgc() {
  local branches=("${(@f)$(wt list --format=json | jq -r '.[] | select(.main_state == "integrated" or .main_state == "empty") | .branch')}")
  if [[ ${#branches[@]} -eq 0 || -z "${branches[1]}" ]]; then
    echo "No integrated worktrees to clean up"
    return 0
  fi
  echo "Removing ${#branches[@]} integrated worktree(s): ${branches[*]}"
  wt remove "${branches[@]}"
}
