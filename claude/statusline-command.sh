#!/usr/bin/env bash
input=$(cat)

# Parse all needed fields in one jq call. We join on the ASCII Unit Separator
# (U+001F) because bash's `read` collapses consecutive whitespace IFS chars
# even when IFS is set to tab — which would silently shift fields when
# git_worktree is empty.
parsed=$(echo "$input" | jq -r '[
  .workspace.current_dir // "",
  .workspace.git_worktree // "",
  .model.display_name // "",
  .context_window.remaining_percentage // "",
  .rate_limits.five_hour.used_percentage // ""
] | join("")')
IFS=$'\x1f' read -r cwd worktree raw_model ctx_remaining five_h_used <<< "$parsed"

# Leaf dir (just the current dir, no parent chain)
leaf=""
[ -n "$cwd" ] && leaf=$(basename "$cwd")

# Git branch — only fetched when we're not in a worktree (we show one or the other)
branch=""
if [ -z "$worktree" ] && [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Shorten a ref name. Only kicks in if > 25 chars. Linear-style branches get cut
# after the first contiguous run of digits; non-digit branches end-truncate with …
shorten_ref() {
  local name="$1"
  [ -z "$name" ] && return
  if [ ${#name} -le 25 ]; then
    printf "%s" "$name"
    return
  fi
  if [[ "$name" =~ ^([^0-9]*[0-9]+) ]]; then
    local cut="${BASH_REMATCH[1]}"
    cut="${cut%[-_/.]}"
    printf "%s" "$cut"
  else
    printf "%s…" "${name:0:25}"
  fi
}

short_worktree=$(shorten_ref "$worktree")
short_branch=$(shorten_ref "$branch")

# Model name transformations:
#   strip leading "Claude "
#   drop " context" / " Context" anywhere (e.g. inside "(1M context)")
#   remove the space between a letter and a digit ("Opus 4.7" → "Opus4.7")
model="$raw_model"
model="${model#Claude }"
model="${model// Context/}"
model="${model// context/}"
model=$(printf "%s" "$model" | sed -E 's/([A-Za-z]) ([0-9])/\1\2/g')

# ANSI styles (terminal remaps per theme)
DIM=$'\033[2m'
BOLD=$'\033[1m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

# cx: context-remaining %. Lower is worse → ramps to red.
fmt_cx() {
  local pct_str="$1"
  [ -z "$pct_str" ] && return
  local pct
  pct=$(printf "%.0f" "$pct_str")
  local style
  if   [ "$pct" -ge 90 ]; then style="$DIM"
  elif [ "$pct" -ge 80 ]; then style="$BOLD"
  elif [ "$pct" -ge 75 ]; then style="$BOLD$YELLOW"
  else                         style="$BOLD$RED"
  fi
  printf "%scx:%d%%%s" "$style" "$pct" "$RESET"
}

# 5h: 5-hour window used %. Higher is worse → ramps to red. Hidden below 25%.
fmt_5h() {
  local pct_str="$1"
  [ -z "$pct_str" ] && return
  local pct
  pct=$(printf "%.0f" "$pct_str")
  [ "$pct" -lt 25 ] && return
  local style
  if   [ "$pct" -le 50 ]; then style="$DIM"
  elif [ "$pct" -le 75 ]; then style="$BOLD"
  elif [ "$pct" -le 90 ]; then style="$BOLD$YELLOW"
  else                         style="$BOLD$RED"
  fi
  printf "%s5h:%d%%%s" "$style" "$pct" "$RESET"
}

# Assemble tokens. Each token carries its own styling.
tokens=()
[ -n "$leaf" ] && tokens+=("${DIM}${leaf}${RESET}")

# Worktree vs branch: when in a worktree, the worktree replaces the branch.
# When the shortened worktree equals the leaf dir, drop the wt: token entirely
# (redundant — leaf already conveys the location).
if [ -n "$short_worktree" ] && [ "$short_worktree" != "$leaf" ]; then
  tokens+=("${DIM}wt:${short_worktree}${RESET}")
elif [ -z "$worktree" ] && [ -n "$short_branch" ]; then
  tokens+=("${DIM}${short_branch}${RESET}")
fi

[ -n "$model" ] && tokens+=("${DIM}${model}${RESET}")

cx_tok=$(fmt_cx "$ctx_remaining")
[ -n "$cx_tok" ] && tokens+=("$cx_tok")

five_tok=$(fmt_5h "$five_h_used")
[ -n "$five_tok" ] && tokens+=("$five_tok")

# Join with a dimmed middle-dot separator
sep="${DIM} · ${RESET}"
line=""
for i in "${!tokens[@]}"; do
  if [ "$i" -eq 0 ]; then
    line="${tokens[$i]}"
  else
    line="${line}${sep}${tokens[$i]}"
  fi
done

printf "%s" "$line"
