#!/usr/bin/env bash
# =============================================================================
# tmux-agent-persistence.sh — tmux side of agent persistence / resurrection.
#
# tmux-resurrect + tmux-continuum already save pane layouts and (some)
# processes across reboots. This script adds the agent-registry glue so that
# restored agent sessions are still visible in the unified dashboard with a
# sane state, and new/killed sessions update the registry automatically.
#
# Usage:
#   tmux-agent-persistence.sh save                     # snapshot registry + tmux agent sessions
#   tmux-agent-persistence.sh restore                  # reconcile registry after a mass restore
#   tmux-agent-persistence.sh reconcile                # alias for restore
#   tmux-agent-persistence.sh on-session-created <session>
#   tmux-agent-persistence.sh on-session-closed  <session>
# =============================================================================

set -euo pipefail

DOTS="${DOTS:-$HOME/dotfiles}"
REGISTRY="$DOTS/scripts/agent-registry.sh"
STATE_DIR="$HOME/.local/state/agents"
SAVE_DIR="$STATE_DIR/tmux-save"
REGISTRY_SNAPSHOT="$SAVE_DIR/registry"
SESSIONS_SNAPSHOT="$SAVE_DIR/tmux-agent-sessions.json"

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

have_jq() { command -v jq >/dev/null 2>&1; }
have_tmux() { command -v tmux >/dev/null 2>&1; }
have_registry() { [[ -x "$REGISTRY" ]]; }

ensure_state_dirs() {
  mkdir -p "$SAVE_DIR" "$REGISTRY_SNAPSHOT"
}

# Return 0 if the tmux session is an agent session.
# Trusts the @is_agent session option first, then falls back to a registry record.
is_agent_session() {
  local session="${1:-}"
  [[ -n "$session" ]] || return 1
  have_tmux || return 1

  local flag
  # -q: suppress "invalid option: @is_agent" noise for non-agent sessions.
  flag="$(tmux show-options -qv -t "$session:" @is_agent 2>/dev/null || true)"
  [[ "$flag" == "1" ]] && return 0

  [[ -f "$STATE_DIR/registry/${session}.json" ]] && return 0
  return 1
}

snapshot_registry() {
  ensure_state_dirs
  rm -f "$REGISTRY_SNAPSHOT"/*.json
  if [[ -d "$STATE_DIR/registry" ]]; then
    cp "$STATE_DIR/registry/"*.json "$REGISTRY_SNAPSHOT"/ 2>/dev/null || true
  fi
}

snapshot_sessions() {
  ensure_state_dirs
  if ! have_jq; then
    echo '[]' > "$SESSIONS_SNAPSHOT"
    return 0
  fi

  local sessions='[]'
  if have_tmux; then
    while IFS= read -r s; do
      [[ -n "$s" ]] || continue
      local is_agent=false worktree=""
      is_agent_session "$s" >/dev/null 2>&1 && is_agent=true || true
      worktree="$(tmux display-message -p -t "$s:" '#{pane_current_path}' 2>/dev/null || true)"
      sessions="$(jq -c \
        --arg s "$s" \
        --argjson ia "$is_agent" \
        --arg wt "$worktree" \
        '. + [{session: $s, is_agent: $ia, worktree: $wt}]' <<< "$sessions")"
    done <<< "$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)"
  fi
  jq . <<< "$sessions" > "$SESSIONS_SNAPSHOT"
}

cmd_save() {
  ensure_state_dirs
  snapshot_registry
  snapshot_sessions
}

cmd_restore() {
  if ! have_jq; then
    echo "tmux-agent-persistence: jq required for restore" >&2
    return 0
  fi
  if ! have_tmux; then
    echo "tmux-agent-persistence: tmux not found" >&2
    return 0
  fi
  if ! have_registry; then
    echo "tmux-agent-persistence: agent-registry.sh not found" >&2
    return 0
  fi

  # Snapshot current state before we touch anything.
  cmd_save

  local records
  records="$("$REGISTRY" list --json 2>/dev/null || echo '[]')"

  while IFS=$'\t' read -r session state; do
    [[ -n "$session" ]] || continue
    if tmux has-session -t "$session" 2>/dev/null; then
      # A restored session is alive but its old agent process is gone.
      # Mark it idle (hooks will update it when the agent speaks again) and
      # clear the stale pid so watchers don't chase a dead process.
      if [[ "$state" != "exited" ]]; then
        "$REGISTRY" set-state "$session" idle 2>/dev/null || true
      fi
      "$REGISTRY" set "$session" pid "" 2>/dev/null || true
      "$REGISTRY" set "$session" updated_at "$(now)" 2>/dev/null || true
    else
      "$REGISTRY" set-state "$session" exited 2>/dev/null || true
    fi
  done <<< "$(jq -r '.[] | select(.multiplexer == "tmux") | [.session, .state] | @tsv' <<< "$records" 2>/dev/null || true)"
}

cmd_reconcile() {
  cmd_restore
}

cmd_on_session_created() {
  local session="${1:-}"
  [[ -n "$session" ]] || return 0

  # Always keep the snapshot current so a later restore has the latest picture.
  snapshot_registry
  snapshot_sessions

  if ! is_agent_session "$session"; then
    return 0
  fi

  if ! have_registry; then
    return 0
  fi

  local record="$STATE_DIR/registry/${session}.json"
  if [[ -f "$record" ]]; then
    # A restored or re-created agent session has no live agent yet.
    "$REGISTRY" set-state "$session" idle 2>/dev/null || true
    "$REGISTRY" set "$session" updated_at "$(now)" 2>/dev/null || true
  else
    local worktree=""
    worktree="$(tmux display-message -p -t "$session:" '#{pane_current_path}' 2>/dev/null || true)"
    "$REGISTRY" register "$session" tmux \
      worktree="${worktree:-$PWD}" \
      agent_cmd="" \
      pid="" 2>/dev/null || true
    "$REGISTRY" set-state "$session" idle 2>/dev/null || true
  fi
}

cmd_on_session_closed() {
  local session="${1:-}"
  [[ -n "$session" ]] || return 0

  snapshot_registry
  snapshot_sessions

  have_registry || return 0
  "$REGISTRY" set-state "$session" exited 2>/dev/null || true
}

cmd="${1:-}"
shift || true

case "$cmd" in
  save)               cmd_save "$@" ;;
  restore|reconcile)  cmd_restore "$@" ;;
  on-session-created) cmd_on_session_created "$@" ;;
  on-session-closed)  cmd_on_session_closed "$@" ;;
  *)
    echo "Usage: tmux-agent-persistence.sh {save|restore|reconcile|on-session-created|on-session-closed}" >&2
    exit 2
    ;;
esac
