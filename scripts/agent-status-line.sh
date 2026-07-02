#!/usr/bin/env bash
# =============================================================================
# agent-status-line.sh — compact agent-state summary for the tmux status bar.
#
# Counts agents across both tmux and Zellij using the unified registry. Emits
# e.g. "⚡2 ✓1 " meaning 2 agents need you and 1 finished a turn.
# Embedded #[...] styles are interpreted by tmux >= 3.2 in #() output.
# =============================================================================
set -euo pipefail

REGISTRY="${DOTS:-$HOME/dotfiles}/scripts/agent-registry.sh"

command -v jq >/dev/null 2>&1 || exit 0

# Gather live sessions once per multiplexer for cheap filtering.
tmux_sessions=""
if command -v tmux >/dev/null 2>&1; then
  tmux_sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)"
fi

zellij_sessions=""
if command -v zellij >/dev/null 2>&1; then
  zellij_sessions="$(zellij list-sessions --no-formatting 2>/dev/null | awk '{print $1}' || true)"
fi

records="$("$REGISTRY" list --json 2>/dev/null || echo '[]')"
state_lines="$(jq -r '.[] | [.multiplexer, .session, .state] | @tsv' <<< "$records" 2>/dev/null || true)"

is_alive() {
  local mux="$1" sess="$2"
  case "$mux" in
    tmux)  grep -qxF "$sess" <<< "$tmux_sessions" ;;
    zellij) grep -qxF "$sess" <<< "$zellij_sessions" ;;
    *) false ;;
  esac
}

waiting=0
done=0
while IFS=$'\t' read -r mux sess state; do
  [[ -n "$mux" ]] || continue
  is_alive "$mux" "$sess" || continue
  case "$state" in
    waiting) waiting=$((waiting + 1)) ;;
    done)    done=$((done + 1)) ;;
  esac
done <<< "$state_lines"

out=""
[ "$waiting" -gt 0 ] && out="${out}#[fg=#f7768e,bold]⚡${waiting}#[default,fg=#565f89] "
[ "$done" -gt 0 ]    && out="${out}#[fg=#9ece6a]✓${done}#[default,fg=#565f89] "
printf '%s' "$out"
