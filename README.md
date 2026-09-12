# Dotfiles

For config I'd like to share across machines. Uses [GNU stow](https://www.gnu.org/software/stow/manual/stow.html) to symlink directories from this git repo at `~/dotfiles` to their appropriate location under `~`.

## Instructions

1. Clone this repo in your root directory.
2. Install `stow`.

```sh
brew install stow
```

3. Symlink all files in current directory.

```sh
stow .
```

## Structure

Currently this repo is structured 1:1 with the desired structure of the managed config files in the root directory. In the future if I want to pick and choose certain program config across different machines I might organize by program. For example, if I wanted to keep `ghostty` config separate:

```
# Current — works well with `stow .`
.config
└── ghostty
    ├── config
    └── themes
        └── ben-dark

# Becomes
ghostty
└── .config
    └── ghostty
        ├── config
        └── themes
            └── ben-dark
```

Then, instead of running `stow .`, I could run `stow ghostty`. Repeat for each program config I want to copy over.
Now that I think about it, a local stow ignore file would probably be a better way to exclude machine-specific config. That way structure is obvious, symlink cmd is always `stow .`, and exclusion is managed via local config.


## Machine-local shell configuration

The shared `.zshrc` loads these optional files from your home directory. Keep them outside this repository.

- `~/.zshrc.local.pre`: startup integrations that must run before the prompt.
- `~/.zshrc.local`: machine-specific exports and secret lookups.
- `~/.zshrc.local.post`: integrations that must run after shared setup.

Kiro hooks belong only in the work Mac’s local pre/post files. The personal Mac keeps its Brave Search Keychain lookup in `.zshrc.local`; each machine keeps its own credentials.

Node is managed by nvm, loaded from `~/.nvm/nvm.sh` with a Homebrew fallback. Install nvm and select a default Node version on each machine separately. Do not add Vite+ or version-specific Node directories to the shared PATH. Global npm tools are installed per Node version.

Before pulling updates, preserve any uncommitted changes. Open a new terminal after syncing and check `command -v node`, `nvm current`, and any global tools you use.
