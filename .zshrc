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

# Create a new clone and branch for parallel development.
# Usage: ga <branch-name> [base-branch]
#
# Optionally reads .gaconfig from repo root:
#   copy = .env
#   copy = .claude
#   postcmd = yarn install
ga() {
  if [[ -z "$1" ]]; then
    echo "Usage: ga <branch-name> [base-branch]"
    return 1
  fi

  # Dependencies
  if ! command -v fzf &>/dev/null; then
    echo "Error: fzf is required but not installed"
    return 1
  fi

  # Ensure we're in a git repo
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: not inside a git repository"
    return 1
  fi

  # Ensure origin exists
  local repo_url
  if ! repo_url="$(git remote get-url origin 2>/dev/null)"; then
    echo "Error: remote 'origin' not found"
    return 1
  fi

  local branch="$1"
  local source_root
  source_root="$(git rev-parse --show-toplevel)"
  local repo_name
  repo_name="$(basename "$source_root")"
  local clone_path="../${repo_name}-${branch}"

  # Prevent collisions
  if [[ -e "$clone_path" ]]; then
    echo "Error: $clone_path already exists"
    return 1
  fi

  # Fetch latest branches
  git fetch --quiet origin

  # Select base branch
  local base_branch="$2"
  if [[ -z "$base_branch" ]]; then
    base_branch="$(
      git branch -r --format='%(refname:short)' |
        sed 's|^origin/||' |
        fzf \
          --height=20 \
          --prompt='Select base branch: ' \
          --query='main'
    )"
  fi

  # Fallback if fzf was cancelled
  if [[ -z "$base_branch" ]]; then
    base_branch="main"
  fi

  echo "Creating clone at $clone_path from $base_branch..."

  # Clone using reference for speed
  if ! git clone --reference "$PWD" "$repo_url" "$clone_path"; then
    echo "Error: clone failed"
    return 1
  fi

  cd "$clone_path" || return 1

  # Ensure base branch exists locally
  if ! git show-ref --verify --quiet "refs/remotes/origin/$base_branch"; then
    echo "Error: base branch '$base_branch' not found on origin"
    return 1
  fi

  git checkout -B "$base_branch" "origin/$base_branch"
  git checkout -b "$branch"

  # Load config from source repo
  local config_file="$source_root/.gaconfig"

  if [[ -f "$config_file" ]]; then
    echo "Loading .gaconfig..."

    # Copy specified files/dirs
    while IFS='= ' read -r key value; do
      # Skip empty lines and comments
      [[ -z "$key" || "$key" == \#* ]] && continue
      # Trim whitespace
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"

      if [[ "$key" == "copy" && -n "$value" ]]; then
        local src="$source_root/$value"
        if [[ -e "$src" ]]; then
          local dest_dir
          dest_dir="$(dirname "$value")"
          [[ "$dest_dir" != "." ]] && mkdir -p "$dest_dir"
          cp -r "$src" "$value"
          echo "  Copied $value"
        else
          echo "  Warning: $value not found, skipping"
        fi
      fi
    done < "$config_file"

    # Run post command
    local postcmd
    postcmd="$(grep -E '^postcmd\s*=' "$config_file" | head -1 | cut -d'=' -f2-)"
    postcmd="${postcmd#"${postcmd%%[![:space:]]*}"}"  # trim leading whitespace
    if [[ -n "$postcmd" ]]; then
      echo "Running postcmd: $postcmd"
      eval "$postcmd"
    fi
  fi

  echo "Created clone at $clone_path on branch '$branch' (based on '$base_branch')"
}

# Remove a cloned repo directory.
# Warns if there are uncommitted changes, unpushed commits, or stashes.
# Usage: gd [--dry-run]
# Run from within the clone you want to delete.
gd() {
  # Dependencies
  if ! command -v gum &>/dev/null; then
    echo "Error: gum is required but not installed"
    return 1
  fi

  local dry_run=false
  if [[ "$1" == "--dry-run" ]]; then
    dry_run=true
  fi

  # Ensure we're in a git repo
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: not inside a git repository"
    return 1
  fi

  local cwd
  cwd="$(pwd)"
  local clone_name
  clone_name="$(basename "$cwd")"

  # Heuristic: refuse to delete if this looks like the primary repo
  if [[ "$clone_name" != *-* ]]; then
    echo "Error: directory name '$clone_name' does not look like a clone"
    echo "Refusing to delete (expected format: <repo>-<branch>)"
    return 1
  fi

  # Uncommitted changes
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "⚠️  Warning: you have uncommitted changes:"
    git status --short
    echo ""
    if ! gum confirm "Delete anyway?"; then
      echo "Aborted"
      return 1
    fi
  fi

  # Unpushed commits
  local unpushed
  unpushed="$(git log --oneline @{upstream}..HEAD 2>/dev/null)"
  if [[ -n "$unpushed" ]]; then
    echo "⚠️  Warning: you have unpushed commits:"
    echo "$unpushed"
    echo ""
    if ! gum confirm "Delete anyway?"; then
      echo "Aborted"
      return 1
    fi
  fi

  # Stashes
  local stashes
  stashes="$(git stash list 2>/dev/null)"
  if [[ -n "$stashes" ]]; then
    echo "⚠️  Warning: you have stashes:"
    echo "$stashes"
    echo ""
    if ! gum confirm "Delete anyway?"; then
      echo "Aborted"
      return 1
    fi
  fi

  echo "About to remove:"
  echo "  $cwd"

  if $dry_run; then
    echo "[dry-run] Nothing was deleted"
    return 0
  fi

  if gum confirm "Remove clone '$clone_name'?"; then
    cd .. || return 1
    rm -rf "$clone_name"
    echo "Removed $clone_name"
  fi
}