#!/usr/bin/env bash
# Fetches status.claude.com and writes the worst current status (across the
# components that affect a Claude Code session) to a one-line cache file.
# Designed to be invoked detached from the statusline so the prompt never
# blocks on the network. On any failure (offline, timeout, parse error) we
# still write to the cache so the staleness check doesn't keep spawning us.

set -u

cache_file="${CLAUDE_STATUS_CACHE:-$HOME/.claude/cache/claude-status}"
mkdir -p "$(dirname "$cache_file")"

# Components we care about. "Claude Code" is the app, the API component is
# the upstream it depends on. Worst status of these two wins.
status=$(curl -fsS --max-time 4 https://status.claude.com/api/v2/summary.json 2>/dev/null \
  | jq -r '
      [ .components[]
        | select(.name == "Claude Code"
              or .name == "Claude API (api.anthropic.com)")
        | .status ]
      | if   any(. == "major_outage")         then "major_outage"
        elif any(. == "partial_outage")       then "partial_outage"
        elif any(. == "under_maintenance")    then "under_maintenance"
        elif any(. == "degraded_performance") then "degraded_performance"
        elif length > 0                       then "operational"
        else "unknown" end
    ' 2>/dev/null)

[ -z "$status" ] && status="unknown"
printf "%s\n" "$status" > "$cache_file"
