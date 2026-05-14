# dotfiles

Personal dotfiles for macOS. Each file in this repo is symlinked into `$HOME`
(without the leading dot prefix — `zshrc` here becomes `~/.zshrc`).

## Install

```sh
git clone git@github.com:sighmin/dotfiles.git ~/Developer/svd/dotfiles
~/Developer/svd/dotfiles/bin/setup
```

`bin/setup` is idempotent. Real files at a target path are backed up with a
`.backup.<timestamp>` suffix; existing symlinks are replaced.

## Files

### Shell

- `zshrc` — zsh: history, prompt (pure), syntax highlighting, autosuggestions,
  fzf, nvm, `g`/`gloc`/`gpoc`/`gpr` git helpers, `ai`/`ai2` natural-language
  shell command helper. Sources `~/.zsh_secrets` (gitignored) if present.
- `bashrc` — sources `~/.fzf.bash`.
- `fzf.zsh`, `fzf.bash` — fzf shell integration.

### Editor

- `nvim/` — LazyVim-based Neovim config (init.lua, lua/config, lua/plugins,
  lazy-lock.json). Symlinked to `~/.config/nvim`.
- `vimrc` — barebones vim config kept around for quick edits in plain vim. No
  plugins; just settings and keymaps.

### Multiplexer

- `tmux.conf` — tmux: `C-a` prefix, vi keys, mouse, smart split nav with vim,
  tpm plugins, atom-one theme via `tmux-dark-notify`.
- `tmux/themes/atom-one/{dark,light}.tmux.conf` — theme files sourced by
  `tmux.conf` and switched by `tmux-dark-notify` on macOS appearance changes.

### Git

- `gitconfig` — user/editor, aliases (`g a`, `g co`, `g pf`, ...), osxkeychain
  credential helper, `main` as the default init branch, `autoSetupRemote` on
  push.
- `gitignore` — global ignore (`.DS_Store`, `.zsh_secrets`, `.claude/`).

### Scripts (`bin/`)

- `setup` — symlinks everything into `$HOME` and installs the screensaver.
- `helpers` — coloured `pinfo`/`psuccess`/`perror`/`not_installed` shell
  helpers sourced by the other scripts.
- `mac-config` — applies a couple of macOS defaults (faster key repeat, hide
  desktop icons). Run manually after `setup` if wanted.

### macOS (`macos/`)

- `Padbury Clock.saver` — screensaver bundle. `setup` copies it into
  `~/Library/Screen Savers/`.

### Homebrew

- `Brewfile` — packages, casks, and taps. Refresh with
  `brew bundle dump --file=Brewfile --force`. Install on a new machine with
  `brew bundle --file=Brewfile`.

## Secrets

API keys and similar live in `~/.zsh_secrets`, which is sourced by `zshrc` and
listed in the global `gitignore`. Nothing sensitive lives in this repo.
