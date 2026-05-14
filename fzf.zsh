# Setup fzf
# ---------
if [[ ! "$PATH" == */Users/svd/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/Users/svd/.fzf/bin"
fi

source <(fzf --zsh)
