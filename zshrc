##################################################
# ENV
##################################################
# For claude
export PATH=$HOME/.local/bin:$PATH
# Kill the lag
export KEYTIMEOUT=1
# Set language
export LANG=en_GB.UTF-8
export LC_ALL=$LANG

##################################################
# Options
##################################################
# Autocomplete options...
# Move cursor to end if word had one match
setopt always_to_end
# Change directory by typing directory name if it's not a command
setopt auto_cd
# Configure history
HISTFILE=$HOME/.zsh_history
HISTSIZE=2500
export SAVEHIST=$HISTSIZE
# Remove older duplicate entries from history
setopt hist_ignore_all_dups
# Remove superfluous blanks from history items
setopt hist_reduce_blanks
# Share history between different instances of the shell
setopt share_history

##################################################
# Functions
##################################################
function current_branch {
  git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null
}

function gloc { git pull origin "$(current_branch)" "$@" }
function gpoc { git push origin "$(current_branch)" "$@" }

# shellcheck disable=SC2215,SC2006
function gpr {
  echo "Opening pull request for $(current_branch)"
  repo=$(git remote -v | grep origin | head -1 | sed "s/git@github.com://" | cut -c8-999 | sed "s/\.git .*//")
  branch=""
  if [ "$1" ]; then
    branch="$1...$(current_branch)"
  else
    branch="main...$(current_branch)"
  fi

  open "https://github.com/$repo/compare/$branch?expand=1"
}

# read secrets from a gitignored file
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

##################################################
# Aliases
##################################################
alias c=clear
alias v=nvim
unalias g 2>/dev/null
g() { if [ $# -eq 0 ]; then git status; else git "$@"; fi }
alias :q=exit
alias cl='claude --dangerously-skip-permissions'
alias mux=tmuxinator

##################################################
# Custom prompt: sindresorhus/pure
##################################################
fpath+=("$(brew --prefix)/share/zsh/site-functions")  
autoload -U promptinit; promptinit
prompt pure

##################################################
# Syntax highlighting in zsh
##################################################
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

##################################################
# Autosuggestions (inline greyed-out completions from history)
##################################################
# Must be sourced AFTER zsh-syntax-highlighting so its widget wrappers layer
# on top of the highlighter (per the plugin's README).
# Accept the full suggestion with → / End; next word with Ctrl+→ or Alt+F.

# Low-contrast theme-aware highlight. Different colours per mode because the
# eye is light-adapted on light backgrounds and needs more luminance gap to
# read, whereas dark mode tolerates much lower contrast comfortably.
# Detection uses `dark-notify --exit` (NSWorkspace-backed) for the same
# reason as tmux/nvim: `defaults read -g AppleInterfaceStyle` sticks at
# "Dark" under macOS Auto-appearance mode.
# Set once at shell startup; run `source ~/.zshrc` to refresh after a flip.
if command -v dark-notify >/dev/null && [[ "$(dark-notify --exit 2>/dev/null)" == "light" ]]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#a0a1a7'   # Atom One Light inactive-window grey
else
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#363a44'   # between Atom One Dark pane border (#3e4451) and bg (#282c34)
fi

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

##################################################
# Vim keybindings
##################################################
# Modal editing on the zsh command line. Esc enters normal mode (vicmd),
# i/a return to insert mode (viins). KEYTIMEOUT=1 above keeps Esc snappy
# (10ms), which is why that was set even before vi mode was enabled.
bindkey -v

# Restore a handful of emacs-style bindings inside insert mode — these are
# muscle memory worth keeping even in a vim setup, and not having them feels
# hostile. Use the modal vicmd keys (h/l/w/b/f/t/etc.) for everything else.
bindkey '^A' beginning-of-line       # Ctrl-A → jump to start of line
bindkey '^E' end-of-line              # Ctrl-E → jump to end of line
bindkey '^P' up-line-or-search        # Ctrl-P → previous history match
bindkey '^N' down-line-or-search      # Ctrl-N → next history match
bindkey '^?' backward-delete-char     # backspace: always delete
bindkey '^H' backward-delete-char     # some terminals send ^H for backspace

##################################################
# Version managers
##################################################
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# bun completions
[ -s "/Users/svd/.bun/_bun" ] && source "/Users/svd/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# asdf
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
#. $(brew --prefix asdf)/libexec/asdf.sh
