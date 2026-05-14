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
# AI: natural language → shell command
##################################################
# Pipes the args to `llm` with a strict system prompt and stages the model's
# reply on the next prompt line via `print -z`, so the suggested command can
# be reviewed/edited before you hit enter.
#
# Setup (one-time):
#   brew install llm                # or: pipx install llm
#   llm install llm-gemini
#   llm keys set gemini             # paste your Google AI Studio key
#
# Usage:
#   $ ai1 find all pngs over 1MB modified this week
#   $ find . -type f -name '*.png' -size +1M -mtime -7█

_ai_system_prompt='You convert a natural-language request into a single shell command for zsh on macOS (BSD coreutils, not GNU). Output ONLY the command, no prose, no explanation, no markdown code fences, no leading $.'

# ai1: minimal — fetch the command and stage it on the next prompt line
function ai {
  (( $# )) || { print -u2 "usage: ai1 <description>"; return 2 }
  local cmd
  cmd=$(llm -m gemini-flash-latest -s "$_ai_system_prompt" -- "$*") || return
  cmd=$(print -r -- "$cmd" | sed '/^[[:space:]]*```/d')   # strip stray fences if model added them
  cmd=${cmd%$'\n'}                                        # trim trailing newline
  print -z -- "$cmd"
}

# ai2: same as ai1, but also echoes the generated command to scrollback for context
function ai2 {
  (( $# )) || { print -u2 "usage: ai2 <description>"; return 2 }
  local cmd
  cmd=$(llm -m gemini-flash-latest -s "$_ai_system_prompt" -- "$*") || return
  cmd=$(print -r -- "$cmd" | sed '/^[[:space:]]*```/d')
  cmd=${cmd%$'\n'}
  print -P "%F{cyan}→ %f$cmd"
  print -z -- "$cmd"
}

##################################################
# Aliases
##################################################
alias c=clear
alias v=nvim
unalias g 2>/dev/null
g() { if [ $# -eq 0 ]; then git status; else git "$@"; fi }
alias :q=exit
alias cl='claude --dangerously-skip-permissions'

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
# Version managers
##################################################
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
