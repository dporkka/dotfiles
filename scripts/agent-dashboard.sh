#!/usr/bin/env bash
# =============================================================================
# agent-dashboard.sh — fzf "mission control" for every running agent.
#
# Lists each agent window across all sessions with its state and a LIVE pane
# preview; Enter jumps straight to it. Bound to `prefix a` (see tmux.conf).
#
# An agent window is one whose session has @is_agent set (spawned via
# agent-worktree.sh) OR any window where @agent_state is set (a Claude Code
# hook has fired — see agent-hook.sh). So both managed and ad-hoc `claude`
# panes show up.
# =============================================================================
set -euo pipefail

command -v fzf >/dev/null 2>&1 || { tmux display-message "agent-dashboard: fzf not found"; exit 0; }

rows="$(tmux list-windows -a -F \
  '#{session_name}:#{window_index}|#{@agent_state}|#{@is_agent}|#{window_name}|#{pane_current_path}' \
  2>/dev/null || true)"

format() {
  local target state isagent name path glyph
  while IFS='|' read -r target state isagent name path; do
    [ -n "$target" ] || continue
    [ -n "$state" ] || [ "$isagent" = "1" ] || continue   # agent windows only
    case "$state" in
      waiting) glyph="⚡ waiting" ;;
      working) glyph="•  working" ;;
      done)    glyph="✓  done" ;;
      *)       glyph="·  idle" ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$target" "$glyph" "$name" "${path/#$HOME/~}"
  done
}

table="$(printf '%s\n' "$rows" | format)"
[ -n "$table" ] || { tmux display-message "no agents running"; exit 0; }

sel="$(printf '%s\n' "$table" | column -t -s $'\t' \
  | fzf --prompt='agent> ' --no-multi --no-sort \
        --header='enter: jump   ·   ⚡ needs you   ✓ done   • working' \
        --preview 'tmux capture-pane -ep -t "$(echo {} | awk "{print \$1}")"' \
        --preview-window=down:65%:wrap || true)"

[ -n "$sel" ] || exit 0
target="$(echo "$sel" | awk '{print $1}')"
session="${target%%:*}"
tmux switch-client -t "$session" 2>/dev/null || tmux attach -t "$session" 2>/dev/null || true
tmux select-window -t "$target" 2>/dev/null || true
