# How to install this Claude Code statusline

Hand this file to your Claude Code agent and say: **"set up this statusline."**
It contains everything the agent needs — two scripts and one settings change.

This guide shows you how to install the statusline demoed in
[`statusline-demo.html`](./statusline-demo.html): a compact line of
`dir · branch · model · cx:NN% · 5h:NN%` whose model colour tracks
status.claude.com and whose meters ramp dim → bold → yellow → red. It never
touches the network on the render path, so the prompt stays instant.

## Before you begin

Confirm the four required tools are on `PATH`. Run:

```sh
for c in bash jq git curl; do command -v "$c" >/dev/null 2>&1 && echo "ok: $c" || echo "MISSING: $c"; done
```

If any report `MISSING`, install it before continuing (`brew install jq`, etc.).
The `·` separator and `…` truncation glyph render best in a Nerd/Unicode font;
with a plain font they degrade to a box but the statusline still works.

## Step 1: Write `~/.claude/statusline-command.sh`

Create the file `~/.claude/statusline-command.sh` with exactly this content:

```bash
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
] | join("\u001f")')
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

# status.claude.com cache. The statusline NEVER hits the network itself —
# it reads the most recent JSON written by status-refresh.sh and, if that
# value is older than 60s, kicks off a detached refresh for next time.
# Worst case the colour is one render stale; the prompt stays instant.
status_cache="${CLAUDE_STATUS_CACHE:-$HOME/.claude/cache/claude-status}"

# `find -mmin -1` matches only if the file was modified in the last minute,
# which is portable between macOS and Linux (unlike `stat -f` vs `stat -c`).
if [ ! -f "$status_cache" ] || [ -z "$(find "$status_cache" -mmin -1 2>/dev/null)" ]; then
  # Detach via subshell so we don't hold the prompt waiting on curl.
  ( "$(dirname "$0")/status-refresh.sh" >/dev/null 2>&1 & )
fi

# Reduce the cached incident list to one status, keeping only incidents that
# affect THIS session's model. An incident title that names a model (family
# word + version, e.g. "Elevated errors on Claude Haiku 4.5") is dropped
# unless it names ours; a title naming no model is assumed to affect every
# model. If our own display name yields no family+version (or the cache is
# stale-format/garbled) we fall back to counting everything / dim. With no
# open incidents at all, the raw component status still gets through — that
# covers maintenance windows and manually-flagged degradation.
claude_status=""
if [ -r "$status_cache" ]; then
  claude_status=$(jq -r --arg model "$raw_model" '
    def mentions: [ ascii_downcase
                    | match("(haiku|sonnet|opus|fable|mythos)[ -]?[0-9]+(\\.[0-9]+)?"; "g").string
                    | gsub("[ -]"; "") ];
    ($model | mentions) as $mine
    | [ .incidents[]
        | (.name | mentions) as $named
        | select(($named | length) == 0
                 or ($mine | length) == 0
                 or any($named[]; . as $n | $mine | index($n)))
        | .impact ] as $impacts
    | if   any($impacts[]; . == "critical") then "major_outage"
      elif any($impacts[]; . == "major")    then "partial_outage"
      elif any($impacts[]; . == "minor")    then "degraded_performance"
      elif (.incidents | length) == 0       then .component_status
      else "operational" end
  ' "$status_cache" 2>/dev/null)
fi

# Pick a style for the model token based on the upstream service status.
# operational / unknown / empty → unchanged (current dim look).
model_style="$DIM"
case "$claude_status" in
  degraded_performance)             model_style="$YELLOW" ;;
  partial_outage|under_maintenance) model_style="$BOLD$YELLOW" ;;
  major_outage)                     model_style="$BOLD$RED" ;;
esac

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

[ -n "$model" ] && tokens+=("${model_style}${model}${RESET}")

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
```

## Step 2: Write `~/.claude/status-refresh.sh`

Create the file `~/.claude/status-refresh.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Fetches status.claude.com and writes a compact JSON cache: the worst raw
# component status (across the components that affect a Claude Code session)
# plus the list of open incidents touching those components. The statusline
# decides per-session whether an incident is relevant — incident titles name
# the affected model ("Elevated errors on Claude Haiku 4.5") while component
# statuses don't, so the model filter has to happen on the incident list.
# Designed to be invoked detached from the statusline so the prompt never
# blocks on the network. On any failure (offline, timeout, parse error) we
# still write to the cache so the staleness check doesn't keep spawning us.

set -u

cache_file="${CLAUDE_STATUS_CACHE:-$HOME/.claude/cache/claude-status}"
mkdir -p "$(dirname "$cache_file")"

# Components we care about. "Claude Code" is the app, the API component is
# the upstream it depends on. Incidents with no component list are kept too —
# better a false yellow than a silently missed outage.
payload=$(curl -fsS --max-time 4 https://status.claude.com/api/v2/summary.json 2>/dev/null \
  | jq -c '
      def relevant: .name == "Claude Code"
                 or .name == "Claude API (api.anthropic.com)";
      {
        component_status:
          ([ .components[] | select(relevant) | .status ]
           | if   any(. == "major_outage")         then "major_outage"
             elif any(. == "partial_outage")       then "partial_outage"
             elif any(. == "under_maintenance")    then "under_maintenance"
             elif any(. == "degraded_performance") then "degraded_performance"
             elif length > 0                       then "operational"
             else "unknown" end),
        incidents:
          [ .incidents[]
            | select((.components | length) == 0 or any(.components[]; relevant))
            | {name, impact} ]
      }
    ' 2>/dev/null)

[ -z "$payload" ] && payload='{"component_status":"unknown","incidents":[]}'
printf "%s\n" "$payload" > "$cache_file"
```

## Step 3: Make both scripts executable

```sh
chmod +x ~/.claude/statusline-command.sh ~/.claude/status-refresh.sh
```

## Step 4: Wire the statusLine into settings

Merge the `statusLine` block into `~/.claude/settings.json` without disturbing
any existing settings. This creates the file if it is absent and overwrites
only the `statusLine` key:

```sh
mkdir -p ~/.claude
[ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
tmp=$(mktemp)
jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}' \
  ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
```

## Step 5: Verify

Render the statusline directly by piping it a sample of the JSON Claude Code
sends on stdin:

```sh
echo '{"workspace":{"current_dir":"/tmp/proj","git_worktree":""},"model":{"display_name":"Claude Opus 4.8"},"context_window":{"remaining_percentage":68},"rate_limits":{"five_hour":{"used_percentage":96}}}' \
  | bash ~/.claude/statusline-command.sh | cat -v
```

Expect a line ending `proj · Opus4.8 · cx:68% · 5h:96%`, with `cat -v` showing
the ANSI escapes (`^[[1;31m`) that colour `cx`/`5h` red at those levels. The
statusline appears in Claude Code from your next prompt onward.

Each token means:

- **`proj`** — current directory (leaf only).
- **`branch`** or **`wt:name`** — git branch, or worktree name when you're in one.
- **`Opus4.8`** — active model; colour follows status.claude.com.
- **`cx:NN%`** — context window remaining (red as it runs low).
- **`5h:NN%`** — 5-hour usage window (hidden below 25%; red as it fills).

For every component in every colour state, open
[`statusline-demo.html`](./statusline-demo.html).

## Adapting this

- **If you keep your dotfiles in a repo:** write the two scripts into your repo
  instead, symlink them to `~/.claude/`, and point the command at the symlink —
  `bash ~/.claude/statusline-command.sh` works either way.
- **If you store the status cache elsewhere:** export `CLAUDE_STATUS_CACHE` to
  an absolute path; both scripts honour it.

## Troubleshooting

- **No colours at all** — your terminal or Claude Code theme may strip ANSI.
  Confirm escapes are emitted with the `cat -v` check in Step 5.
- **`jq: command not found`** — install `jq` (`brew install jq`); the statusline
  cannot parse stdin without it.
- **Separator shows as `▯`** — the font lacks the `·`/`…` glyphs. Switch to a
  Nerd or Unicode-complete font; behaviour is unaffected.
- **Model token never changes colour** — `curl` to status.claude.com is blocked,
  or the cache is empty. The line still works; the model token just stays dim.
  Run `bash ~/.claude/status-refresh.sh && cat ~/.claude/cache/claude-status` to
  check the fetch.

## See also

- [`statusline-demo.html`](./statusline-demo.html) — live demo of every
  component state, and the reasoning behind the design.
