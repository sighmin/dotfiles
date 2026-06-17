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
