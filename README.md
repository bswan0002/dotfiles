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
