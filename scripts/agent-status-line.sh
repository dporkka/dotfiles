#!/usr/bin/env bash
# =============================================================================
# agent-status-line.sh — compact agent-state summary for the tmux status bar.
#
# Counts tmux agents via the unified registry. Emits e.g. "⚡2 ✓1 " meaning
# 2 agents need you and 1 finished a turn.
# Embedded #[...] styles are interpreted by tmux >= 3.2 in #() output.
# =============================================================================
set -euo pipefail

REGISTRY="${DOTS:-$HOME/dotfiles}/scripts/agent-registry.sh"

command -v jq >/dev/null 2>&1 || exit 0

# Gather live tmux sessions once for cheap filtering.
tmux_sessions=""
if command -v tmux >/dev/null 2>&1; then
  tmux_sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)"
fi

records="$("$REGISTRY" list --json 2>/dev/null || echo '[]')"
state_lines="$(jq -r '.[] | select(.multiplexer == "tmux") | [.session, .state] | @tsv' <<< "$records" 2>/dev/null || true)"

is_alive() {
  local sess="$1"
  grep -qxF "$sess" <<< "$tmux_sessions"
}

waiting=0
done=0
while IFS=$'\t' read -r sess state; do
  [[ -n "$sess" ]] || continue
  is_alive "$sess" || continue
  case "$state" in
    waiting) waiting=$((waiting + 1)) ;;
    done)    done=$((done + 1)) ;;
  esac
done <<< "$state_lines"

out=""
[ "$waiting" -gt 0 ] && out="${out}#[fg=#f7768e,bold]⚡${waiting}#[default,fg=#565f89] "
[ "$done" -gt 0 ]    && out="${out}#[fg=#9ece6a]✓${done}#[default,fg=#565f89] "
printf '%s' "$out"
