# Machine-local startup hooks (for integrations that must run before the prompt).
[[ -f "$HOME/.zshrc.local.pre" ]] && source "$HOME/.zshrc.local.pre"

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
# Machine-local secrets/config. Not tracked by dotfiles.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export BAT_THEME="Visual Studio Dark+"

export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
elif command -v brew >/dev/null 2>&1; then
  nvm_brew_prefix="$(brew --prefix)/opt/nvm"
  [[ -s "$nvm_brew_prefix/nvm.sh" ]] && source "$nvm_brew_prefix/nvm.sh"
  unset nvm_brew_prefix
fi

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
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

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
alias shrug="printf '%s' '¯\\_(ツ)_/¯' | pbcopy"

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


# opencode
export PATH="$HOME/.opencode/bin:$PATH"
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

# Remove current worktree, force-deleting the branch when its PR is merged
wtr() {
  local pr_state branch git_dir ref_status
  local workspace_id="${HERDR_WORKSPACE_ID:-}"
  branch="$(git symbolic-ref --quiet HEAD)" || branch=""
  git_dir="$(git rev-parse --path-format=absolute --git-common-dir)" || return $?
  pr_state="$(gh pr view --json state --jq '.state' 2>/dev/null)" || pr_state=""

  if [[ "$pr_state" == "MERGED" ]]; then
    wt remove -D --no-hooks "$@" || return $?
  else
    wt remove --no-hooks "$@" || return $?
  fi

  if [[ -n "$workspace_id" && -n "$branch" ]]; then
    if git --git-dir="$git_dir" show-ref --verify --quiet "$branch"; then
      echo "Branch still exists; leaving Herdr workspace open."
    else
      ref_status=$?
      if [[ "$ref_status" -eq 1 ]]; then
        herdr workspace close "$workspace_id"
      else
        echo "Could not confirm branch deletion; leaving Herdr workspace open." >&2
        return "$ref_status"
      fi
    fi
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

# Copy the current worktree's ignored AGENTS.md to the repo's other worktrees
sync-agents() {
  local root agents wt exclude

  root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Not inside a git repo" >&2
    return 1
  }

  agents="$root/AGENTS.md"
  if [[ ! -f "$agents" ]]; then
    echo "No AGENTS.md found at $agents" >&2
    return 1
  fi

  git -C "$root" worktree list --porcelain |
    awk '/^worktree / { sub(/^worktree /, ""); print }' |
    while IFS= read -r wt; do
      if [[ "$wt" == "$root" ]]; then
        continue
      fi

      if [[ -d "$wt/AGENTS.md" ]]; then
        echo "Skipping $wt/AGENTS.md because it is a directory" >&2
        continue
      fi

      cp "$agents" "$wt/AGENTS.md"
      echo "Updated $wt/AGENTS.md"

      exclude="$(git -C "$wt" rev-parse --git-path info/exclude)"
      mkdir -p "${exclude:h}"
      if ! grep -qxF "AGENTS.md" "$exclude" 2>/dev/null; then
        echo "AGENTS.md" >> "$exclude"
        echo "Ignored AGENTS.md in $wt"
      fi
    done
}

# Kill the process listening on a port, escalating after 3 seconds
kp() {
  local port="$1"
  local -a pids alive

  if [[ "$port" != <-> ]] || (( port < 1 || port > 65535 )); then
    echo "Usage: kp <port>" >&2
    return 2
  fi

  pids=($(lsof -tiTCP:"$port" -sTCP:LISTEN))
  if (( ${#pids} == 0 )); then
    echo "No process listening on port $port"
    return 1
  fi

  echo "Sending SIGTERM to PID(s): ${pids[*]}"
  kill -TERM "${pids[@]}"

  for _ in {1..30}; do
    alive=()
    for pid in "${pids[@]}"; do
      kill -0 "$pid" 2>/dev/null && alive+=("$pid")
    done

    if (( ${#alive} == 0 )); then
      echo "Stopped gracefully"
      return 0
    fi

    sleep 0.1
  done

  echo "Forcing shutdown of PID(s): ${alive[*]}"
  kill -KILL "${alive[@]}"
}

# Machine-local integrations that must run after shared shell setup.
[[ -f "$HOME/.zshrc.local.post" ]] && source "$HOME/.zshrc.local.post"
