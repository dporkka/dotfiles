#!/usr/bin/env bash
# =============================================================================
# agent-registry.sh — lightweight file-based registry for tmux agents.
#
# Unifies tmux agents so dashboards/status lines can see all agents in one
# place. Records survive tmux detach/restart because they live on disk under
# ~/.local/state/agents/registry/.
#
# Usage:
#   agent-registry.sh register <session> tmux [key=value ...]
#   agent-registry.sh set-state <session> <state>
#   agent-registry.sh set <session> <key> <value>
#   agent-registry.sh get <session> [key]
#   agent-registry.sh list [--json]
#   agent-registry.sh prune
#   agent-registry.sh clear
#   agent-registry.sh snapshot [name]
#   agent-registry.sh list-snapshots
#   agent-registry.sh restore [name|latest]
#   agent-registry.sh resurrect [--dry-run]
#
# States: idle | working | waiting | done | exited
# =============================================================================

set -euo pipefail

REGISTRY_DIR="${AGENT_REGISTRY_DIR:-$HOME/.local/state/agents/registry}"
SNAPSHOT_DIR="${AGENT_SNAPSHOT_DIR:-$HOME/.local/state/agents/snapshots}"
mkdir -p "$REGISTRY_DIR" "$SNAPSHOT_DIR"

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
snapshot_name() { date -u +"%Y%m%d-%H%M%S"; }

record_path() { echo "$REGISTRY_DIR/${1}.json"; }

ensure_jq() {
  command -v jq >/dev/null 2>&1 || { echo "agent-registry: jq required" >&2; exit 1; }
}

cmd_register() {
  local session="${1:?Usage: register <session> <multiplexer> [key=value ...]}"
  local multiplexer="${2:?Usage: register <session> <multiplexer> [key=value ...]}"
  shift 2

  [[ "$multiplexer" == "tmux" ]] \
    || { echo "agent-registry: multiplexer must be tmux" >&2; exit 2; }

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

# Check whether a tmux session is still alive.
session_alive() {
  local session="$2"
  tmux has-session -t "$session" 2>/dev/null
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

# Snapshot the entire registry to a single timestamped JSON file. Snapshots are
# the resurrection source of truth: they survive registry clears/prunes and let
# you bring back agent metadata (worktree, branch, base, cmd) even when the
# original tmux session is gone.
cmd_snapshot() {
  local name="${1:-$(snapshot_name)}"
  local file="$SNAPSHOT_DIR/${name}.json"
  mkdir -p "$SNAPSHOT_DIR"
  cmd_list --json > "$file"
  local count
  count="$(jq 'length' "$file" 2>/dev/null || echo 0)"
  echo "Saved snapshot: $file ($count record(s))"
}

cmd_list_snapshots() {
  local found=0
  for f in "$SNAPSHOT_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    found=1
    local name size count mtime
    name="$(basename "$f" .json)"
    size="$(stat -c%s "$f" 2>/dev/null || echo 0)"
    count="$(jq 'length' "$f" 2>/dev/null || echo 0)"
    mtime="$(date -r "$f" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || stat -c '%y' "$f" 2>/dev/null | cut -d'.' -f1 || echo "-")"
    printf '%s\t%s bytes\t%s record(s)\t%s\n' "$name" "$size" "$count" "$mtime"
  done
  [[ "$found" -eq 0 ]] && echo "No snapshots."
  return 0
}

# Restore registry records from a snapshot. Existing records are removed first;
# records whose session is still alive in tmux are preserved.
cmd_restore() {
  local name="${1:-latest}"
  local file=""
  if [[ "$name" == "latest" ]]; then
    file="$(ls -t "$SNAPSHOT_DIR"/*.json 2>/dev/null | head -n1 || true)"
  else
    file="$SNAPSHOT_DIR/${name}.json"
  fi
  [[ -n "$file" && -f "$file" ]] || { echo "agent-registry: no snapshot found for '$name'" >&2; exit 1; }

  local restored=0
  while IFS= read -r rec; do
    local session multiplexer
    session="$(jq -r '.session // empty' <<< "$rec" 2>/dev/null || true)"
    multiplexer="$(jq -r '.multiplexer // empty' <<< "$rec" 2>/dev/null || true)"
    [[ -n "$session" && -n "$multiplexer" ]] || continue
    echo "$rec" > "$REGISTRY_DIR/${session}.json"
    restored=$((restored + 1))
  done < <(jq -c '.[]' "$file" 2>/dev/null || true)
  echo "Restored $restored record(s) from $(basename "$file")."
}

# Resurrect dead agent sessions from the latest snapshot. For each record whose
# tmux session no longer exists, re-launch it using the recorded
# worktree/branch/agent_cmd. Best-effort: missing git worktrees or unknown
# agents are skipped with a message instead of failing.
cmd_resurrect() {
  local dry_run=false
  [[ "${1:-}" == "--dry-run" ]] && dry_run=true

  local file
  file="$(ls -t "$SNAPSHOT_DIR"/*.json 2>/dev/null | head -n1 || true)"
  [[ -n "$file" && -f "$file" ]] || { echo "agent-registry: no snapshots to resurrect" >&2; exit 1; }

  local resurrected=0
  while IFS= read -r rec; do
    local session multiplexer worktree branch base agent_cmd
    session="$(jq -r '.session // empty' <<< "$rec" 2>/dev/null || true)"
    multiplexer="$(jq -r '.multiplexer // empty' <<< "$rec" 2>/dev/null || true)"
    [[ -n "$session" && -n "$multiplexer" ]] || continue
    [[ "$multiplexer" == "tmux" ]] || continue
    session_alive "$multiplexer" "$session" && continue

    worktree="$(jq -r '.worktree // empty' <<< "$rec" 2>/dev/null || true)"
    branch="$(jq -r '.branch // empty' <<< "$rec" 2>/dev/null || true)"
    base="$(jq -r '.base // empty' <<< "$rec" 2>/dev/null || true)"
    agent_cmd="$(jq -r '.agent_cmd // empty' <<< "$rec" 2>/dev/null || true)"
    agent="$(jq -r '.agent // empty' <<< "$rec" 2>/dev/null || true)"
    prompt="$(jq -r '.prompt // empty' <<< "$rec" 2>/dev/null || true)"

    # Prefer explicit agent/prompt fields; fall back to parsing agent_cmd.
    if [[ -z "$agent" && -n "$agent_cmd" ]]; then
      agent="${agent_cmd%% *}"
      if [[ "$agent_cmd" == *" "* ]]; then
        prompt="${agent_cmd#* }"
      fi
    fi
    [[ -n "$agent" ]] || agent="claude"

    if $dry_run; then
      echo "[dry-run] would resurrect tmux session '$session' (agent: $agent)"
      continue
    fi

    if [[ -n "$branch" && -n "$worktree" && -n "$base" ]]; then
      # Worktree agent: recreate worktree + session.
      if [[ -d "$worktree" ]]; then
        echo "Resurrecting tmux worktree agent: $session"
        if [[ -n "$prompt" ]]; then
          "$HOME/dotfiles/scripts/agent-worktree.sh" "$branch" --base "$base" --agent "$agent" "$prompt"
        else
          "$HOME/dotfiles/scripts/agent-worktree.sh" "$branch" --base "$base" --agent "$agent"
        fi
        resurrected=$((resurrected + 1))
      else
        echo "Skipping $session: worktree missing ($worktree)"
      fi
    elif [[ -n "$worktree" ]]; then
      # Session agent: recreate a plain tmux session.
      if [[ -d "$worktree" ]]; then
        echo "Resurrecting tmux session agent: $session"
        (cd "$worktree" && "$HOME/dotfiles/scripts/agent-session.sh" "$session" "$agent"${prompt:+ }$prompt)
        resurrected=$((resurrected + 1))
      else
        echo "Skipping $session: worktree missing ($worktree)"
      fi
    else
      echo "Skipping $session: no worktree to resurrect"
    fi
  done < <(jq -c '.[]' "$file" 2>/dev/null || true)
  echo "Resurrected $resurrected session(s)."
}

ensure_jq

cmd="${1:-}"
shift || true

case "$cmd" in
  register)        cmd_register "$@" ;;
  set-state)       cmd_set_state "$@" ;;
  set)             cmd_set "$@" ;;
  get)             cmd_get "$@" ;;
  list)            cmd_list "$@" ;;
  prune)           cmd_prune "$@" ;;
  clear)           cmd_clear "$@" ;;
  snapshot)        cmd_snapshot "$@" ;;
  list-snapshots)  cmd_list_snapshots "$@" ;;
  restore)         cmd_restore "$@" ;;
  resurrect)       cmd_resurrect "$@" ;;
  *)
    echo "Usage: agent-registry.sh {register|set-state|set|get|list|prune|clear|snapshot|list-snapshots|restore|resurrect}" >&2
    exit 2
    ;;
esac
