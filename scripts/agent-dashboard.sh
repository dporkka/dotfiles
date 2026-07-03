#!/usr/bin/env bash
# =============================================================================
# agent-dashboard.sh — unified fzf "mission control" for every running agent.
#
# Lists every agent recorded in ~/.local/state/agents/registry/, regardless of
# whether it lives in tmux or Zellij. Enter jumps straight to it.
# Bound to `prefix a` in tmux.conf and `Alt d` / `Ctrl-b a` in config.kdl.
# =============================================================================
set -euo pipefail

REGISTRY="${DOTS:-$HOME/dotfiles}/scripts/agent-registry.sh"

# Preview mode: invoked by fzf with the selected line as the second argument.
if [[ "${1:-}" == "--preview" ]]; then
  line="${2:-}"
  [[ -n "$line" ]] || exit 0
  session="$(awk -F'\t' '{gsub(/[[:space:]]+$/, "", $1); print $1}' <<< "$line")"
  mux="$(awk -F'\t' '{gsub(/[[:space:]]+$/, "", $2); print $2}' <<< "$line")"
  case "$mux" in
    tmux)
      tmux capture-pane -ep -t "${session}:1" 2>/dev/null \
        || echo "tmux session '${session}' not reachable"
      ;;
    zellij)
      zellij --session "$session" action list-tabs 2>/dev/null \
        || echo "zellij session '${session}' not reachable"
      ;;
    *)
      echo "unknown multiplexer: $mux"
      ;;
  esac
  exit 0
fi

command -v jq >/dev/null 2>&1 || { echo "agent-dashboard: jq required" >&2; exit 0; }
command -v fzf >/dev/null 2>&1 || { echo "agent-dashboard: fzf not found" >&2; exit 0; }

# Drop stale records so the dashboard reflects reality.
"$REGISTRY" prune >/dev/null 2>&1 || true

records="$("$REGISTRY" list --json 2>/dev/null || echo '[]')"
[[ "$records" != "[]" ]] || { echo "no agents running"; exit 0; }

# Build display lines: session<TAB>mux<TAB>state-glyph<TAB>name<TAB>worktree<TAB>agent_cmd
lines="$(jq -r --arg home "$HOME" '.[] | [
  .session,
  .multiplexer,
  (.state |
    if . == "waiting" then "⚡ waiting"
    elif . == "working" then "•  working"
    elif . == "done" then "✓  done"
    elif . == "exited" then "✗  exited"
    else "·  idle"
    end),
  (.branch // .session),
  (.worktree // "-" | sub("^" + $home + "/"; "~/")),
  (.agent_cmd // "-")
] | @tsv' <<< "$records" 2>/dev/null || true)"

[[ -n "$lines" ]] || { echo "no agents running"; exit 0; }

sel="$(printf '%s\n' "$lines" \
  | fzf --prompt='agent> ' --no-multi --no-sort \
        --header='enter: jump   ·   ⚡ waiting   ✓ done   • working   ✗ exited   · idle' \
        --delimiter '\t' \
        --preview "$0 --preview {}" \
        --preview-window=down:65%:wrap || true)"

[[ -n "$sel" ]] || exit 0

session="$(awk -F'\t' '{gsub(/[[:space:]]+$/, "", $1); print $1}' <<< "$sel")"
mux="$(awk -F'\t' '{gsub(/[[:space:]]+$/, "", $2); print $2}' <<< "$sel")"

case "$mux" in
  tmux)
    if [[ -n "${TMUX:-}" ]]; then
      tmux switch-client -t "$session" 2>/dev/null || true
      tmux select-window -t "${session}:1" 2>/dev/null || true
    else
      tmux attach -t "$session" 2>/dev/null || true
    fi
    ;;
  zellij)
    if [[ -n "${ZELLIJ:-}" ]]; then
      zellij action switch-session "$session" 2>/dev/null || true
    else
      zellij attach "$session" 2>/dev/null || true
    fi
    ;;
esac
