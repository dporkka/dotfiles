#!/usr/bin/env bash
# =============================================================================
# agent-registry.sh — lightweight file-based registry for AI agents.
#
# Unifies tmux and Zellij agents so dashboards/status lines can see all agents
# in one place. Records survive multiplexer detach/restart because they live on
# disk under ~/.local/state/agents/registry/.
#
# Usage:
#   agent-registry.sh register <session> <multiplexer> [key=value ...]
#   agent-registry.sh set-state <session> <state>
#   agent-registry.sh set <session> <key> <value>
#   agent-registry.sh get <session> [key]
#   agent-registry.sh list [--json]
#   agent-registry.sh prune
#   agent-registry.sh clear
#
# States: idle | working | waiting | done | exited
# =============================================================================

set -euo pipefail

REGISTRY_DIR="${AGENT_REGISTRY_DIR:-$HOME/.local/state/agents/registry}"
mkdir -p "$REGISTRY_DIR"

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

record_path() { echo "$REGISTRY_DIR/${1}.json"; }

ensure_jq() {
  command -v jq >/dev/null 2>&1 || { echo "agent-registry: jq required" >&2; exit 1; }
}

cmd_register() {
  local session="${1:?Usage: register <session> <multiplexer> [key=value ...]}"
  local multiplexer="${2:?Usage: register <session> <multiplexer> [key=value ...]}"
  shift 2

  [[ "$multiplexer" == "tmux" || "$multiplexer" == "zellij" ]] \
    || { echo "agent-registry: multiplexer must be tmux or zellij" >&2; exit 2; }

  local file
  file="$(record_path "$session")"
  local ts
  ts="$(now)"

  # Build a JSON object from key=value pairs.
  local extra='{}'
  for kv in "$@"; do
    if [[ "$kv" == *=* ]]; then
      local k="${kv%%=*}"
      local v="${kv#*=}"
      extra="$(jq -c --arg k "$k" --arg v "$v" '. + {($k): $v}' <<< "$extra")"
    fi
  done

  jq -n \
    --arg session "$session" \
    --arg multiplexer "$multiplexer" \
    --arg state "idle" \
    --arg started_at "$ts" \
    --arg updated_at "$ts" \
    --argjson extra "$extra" \
    '{
      session: $session,
      multiplexer: $multiplexer,
      state: $state,
      started_at: $started_at,
      updated_at: $updated_at
    } + $extra' > "$file"
}

cmd_set_state() {
  local session="${1:?Usage: set-state <session> <state>}"
  local state="${2:?Usage: set-state <session> <state>}"
  local file
  file="$(record_path "$session")"
  [[ -f "$file" ]] || { echo "agent-registry: no record for $session" >&2; exit 1; }
  jq --arg state "$state" --arg updated_at "$(now)" \
    '.state = $state | .updated_at = $updated_at' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

cmd_set() {
  local session="${1:?Usage: set <session> <key> <value>}"
  local key="${2:?Usage: set <session> <key> <value>}"
  local value="${3:?Usage: set <session> <key> <value>}"
  local file
  file="$(record_path "$session")"
  [[ -f "$file" ]] || { echo "agent-registry: no record for $session" >&2; exit 1; }
  jq --arg key "$key" --arg value "$value" --arg updated_at "$(now)" \
    '.[$key] = $value | .updated_at = $updated_at' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

cmd_get() {
  local session="${1:?Usage: get <session> [key]}"
  local key="${2:-}"
  local file
  file="$(record_path "$session")"
  [[ -f "$file" ]] || { echo "agent-registry: no record for $session" >&2; exit 1; }
  if [[ -n "$key" ]]; then
    jq -r --arg key "$key" '.[$key] // empty' "$file"
  else
    jq . "$file"
  fi
}

# Check whether a session is still alive in its multiplexer.
session_alive() {
  local multiplexer="$1"
  local session="$2"
  case "$multiplexer" in
    tmux)
      tmux has-session -t "$session" 2>/dev/null
      ;;
    zellij)
      zellij list-sessions --no-formatting 2>/dev/null | awk '{print $1}' | grep -qxF "$session"
      ;;
    *)
      return 1
      ;;
  esac
}

cmd_list() {
  local json=false
  [[ "${1:-}" == "--json" ]] && json=true

  local records='[]'
  for f in "$REGISTRY_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    records="$(jq -c --slurpfile rec "$f" '. + $rec' <<< "$records")"
  done

  if $json; then
    jq . <<< "$records"
  else
    jq -r '.[] | "\(.session)\t\(.multiplexer)\t\(.state)\t\(.worktree // "-")\t\(.agent_cmd // "-")"' <<< "$records"
  fi
}

cmd_prune() {
  local removed=0
  for f in "$REGISTRY_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    local session multiplexer
    session="$(jq -r '.session // empty' "$f" 2>/dev/null || true)"
    multiplexer="$(jq -r '.multiplexer // empty' "$f" 2>/dev/null || true)"
    [[ -n "$session" && -n "$multiplexer" ]] || continue
    if ! session_alive "$multiplexer" "$session"; then
      rm "$f"
      removed=$((removed + 1))
    fi
  done
  echo "Pruned $removed dead agent record(s)."
}

cmd_clear() {
  rm -f "$REGISTRY_DIR"/*.json
  echo "Cleared agent registry."
}

ensure_jq

cmd="${1:-}"
shift || true

case "$cmd" in
  register)   cmd_register "$@" ;;
  set-state)  cmd_set_state "$@" ;;
  set)        cmd_set "$@" ;;
  get)        cmd_get "$@" ;;
  list)       cmd_list "$@" ;;
  prune)      cmd_prune "$@" ;;
  clear)      cmd_clear "$@" ;;
  *)
    echo "Usage: agent-registry.sh {register|set-state|set|get|list|prune|clear}" >&2
    exit 2
    ;;
esac
