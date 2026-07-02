#!/usr/bin/env bash
# =============================================================================
# zellij-agent-dashboard.sh — fzf "mission control" for Zellij agent sessions
#
# Lists running Zellij sessions with a preview of their tabs; Enter attaches to
# the selected session or switches to it if already inside Zellij.
# Mirrors scripts/agent-dashboard.sh for tmux; both multiplexers coexist.
# =============================================================================
set -euo pipefail

command -v fzf >/dev/null 2>&1 || { echo "zellij-agent-dashboard: fzf not found" >&2; exit 0; }
command -v zellij >/dev/null 2>&1 || { echo "zellij-agent-dashboard: zellij not found" >&2; exit 0; }

# Fetch sessions: NAME [CREATED] [ATTACHED]
sessions="$(zellij list-sessions --no-formatting 2>/dev/null | awk '{print $1}' || true)"
[ -n "$sessions" ] || { echo "no zellij sessions running"; exit 0; }

# Build a list of agent-looking sessions. A session qualifies if it has a tab
# named "agent" (set by the agent.kdl layout) or if its name looks like an
# agent-session.sh timestamped session. If no agents are found, fall back to
# all sessions.
agent_lines=()
all_lines=()
while IFS= read -r session; do
  [[ -n "$session" ]] || continue
  tabs="$(zellij --session "$session" action list-tabs 2>/dev/null \
    | awk 'NR>1 {print $3}' \
    | paste -sd ',' - || true)"
  line="$session [$tabs]"
  all_lines+=("$line")
  if [[ "$tabs" == *"agent"* ]] || [[ "$session" =~ ^[a-zA-Z0-9_-]+-[0-9]{8}-[0-9]{6}$ ]]; then
    agent_lines+=("$line")
  fi
done <<< "$sessions"

if [[ ${#agent_lines[@]} -gt 0 ]]; then
  display_lines=("${agent_lines[@]}")
else
  display_lines=("${all_lines[@]}")
fi

sel="$(printf '%s\n' "${display_lines[@]}" \
  | fzf --prompt='zellij agent> ' --no-multi --no-sort \
        --header='enter: attach/switch   ·   agent sessions only' \
        --preview 's=$(echo {} | awk "{print \\$1}"); zellij --session "$s" action list-tabs 2>/dev/null || echo "unable to list tabs"' \
        --preview-window=down:50%:wrap || true)"

[ -n "$sel" ] || exit 0
session="$(echo "$sel" | awk '{print $1}')"

if [[ -n "${ZELLIJ:-}" ]]; then
  zellij action switch-session "$session"
else
  zellij attach "$session"
fi
