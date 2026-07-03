#!/usr/bin/env bash
# =============================================================================
# agent-resurrect.sh — bring dead agent records back to life.
#
# Scans ~/.local/state/agents/registry/ for records whose multiplexer session is
# no longer alive but whose state is not "exited", then recreates the session
# using the recorded worktree/branch/base/agent_cmd.
#
# Worktree agents are relaunched through agent-worktree.sh / zellij-agent-worktree.sh
# so the full agent pane + watcher + review layout is restored. Simple session
# agents are recreated as a fresh tmux/zellij session in the recorded directory.
#
# Usage:
#   agent-resurrect.sh list               # show resurrectable records
#   agent-resurrect.sh all [--dry-run]    # resurrect every eligible record
#   agent-resurrect.sh <session>          # resurrect a specific record
#   agent-resurrect.sh <session> --dry-run
# =============================================================================

set -euo pipefail

REGISTRY="${DOTS:-$HOME/dotfiles}/scripts/agent-registry.sh"
REGISTRY_DIR="${AGENT_REGISTRY_DIR:-$HOME/.local/state/agents/registry}"
LAYOUT_DIR="${DOTS:-$HOME/dotfiles}/config/zellij/layouts"
LAYOUT="${LAYOUT_DIR}/agent.kdl"

usage() {
  echo "Usage: $(basename "$0") {list|all|<session>} [--dry-run]" >&2
  exit 2
}

# Check whether a session is still alive in its multiplexer.
session_alive() {
  local mux="$1"
  local sess="$2"
  case "$mux" in
    tmux)
      tmux has-session -t "$sess" 2>/dev/null
      ;;
    zellij)
      zellij list-sessions --no-formatting 2>/dev/null | awk '{print $1}' | grep -qxF "$sess"
      ;;
    *)
      return 1
      ;;
  esac
}

# List dead-but-not-exited records that are candidates for resurrection.
list_dead() {
  local records
  records="$("$REGISTRY" list --json 2>/dev/null || echo '[]')"
  jq -r '.[] | select(.state != "exited") | "\(.session)\t\(.multiplexer)\t\(.state)\t\(.worktree // "-")\t\(.agent_cmd // "-")"' <<< "$records" \
    | while IFS=$'\t' read -r session mux state worktree agent_cmd; do
        [[ -n "$session" && -n "$mux" ]] || continue
        if ! session_alive "$mux" "$session"; then
          printf '%s\t%s\t%s\t%s\t%s\n' "$session" "$mux" "$state" "$worktree" "$agent_cmd"
        fi
      done
}

# Resurrect an agent that was launched in a git worktree.
resurrect_worktree() {
  local session="$1"
  local mux="$2"
  local worktree="$3"
  local branch="$4"
  local base="$5"
  local agent_cmd="$6"
  local agent="$7"
  local prompt="$8"
  local dry_run="$9"

  # Locate the main repository root. If the worktree still exists, ask git.
  # Otherwise fall back to the naming convention used by agent-worktree.sh:
  #   worktree = <repo-parent>/<repo-name>-<branch-slug>
  #   session  = <repo-name>-<branch-slug>
  local common_dir="" repo_root slug repo_name
  if [[ -d "$worktree" ]]; then
    common_dir="$(cd "$worktree" && git rev-parse --git-common-dir 2>/dev/null || true)"
    if [[ -n "$common_dir" && "$common_dir" != /* ]]; then
      common_dir="$worktree/$common_dir"
    fi
  fi

  if [[ -n "$common_dir" && -d "$common_dir" ]]; then
    repo_root="$(dirname "$common_dir")"
  else
    slug="${branch//\//-}"
    repo_name="${session%"-$slug"}"
    repo_root="$(dirname "$worktree")/${repo_name:-repo}"
  fi

  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "resurrect: cannot find git repo root for $session (tried $repo_root)" >&2
    return 1
  fi

  # Prefer the recorded agent/prompt fields; fall back to a best-effort parse
  # of agent_cmd for older registry records.
  local agent_arg prompt_arg
  if [[ -n "$agent" ]]; then
    agent_arg="$agent"
    prompt_arg="$prompt"
  else
    agent_arg="${agent_cmd%% *}"
    if [[ "$agent_cmd" == *" "* ]]; then
      prompt_arg="${agent_cmd#* }"
    else
      prompt_arg=""
    fi
  fi

  local base_arg="${base:-main}"
  local launcher
  case "$mux" in
    tmux)  launcher="$HOME/dotfiles/scripts/agent-worktree.sh" ;;
    zellij) launcher="$HOME/dotfiles/scripts/zellij-agent-worktree.sh" ;;
    *)     echo "resurrect: unknown multiplexer '$mux'" >&2; return 1 ;;
  esac

  if [[ "$dry_run" == true ]]; then
    echo "Would resurrect $mux worktree session $session in $repo_root:"
    echo "  $launcher \"$branch\" --base \"$base_arg\" --agent \"$agent_arg\"${prompt_arg:+ -- }$prompt_arg"
    return 0
  fi

  echo "Resurrecting $mux worktree session $session ..."
  (
    cd "$repo_root"
    if [[ -n "$prompt_arg" ]]; then
      "$launcher" "$branch" --base "$base_arg" --agent "$agent_arg" -- "$prompt_arg"
    else
      "$launcher" "$branch" --base "$base_arg" --agent "$agent_arg"
    fi
  )

  "$REGISTRY" set-state "$session" idle >/dev/null 2>&1 || true
}

# Resurrect a simple (non-worktree) agent session.
resurrect_simple() {
  local session="$1"
  local mux="$2"
  local worktree="$3"
  local agent_cmd="$4"
  local dry_run="$5"

  if [[ ! -d "$worktree" ]]; then
    echo "resurrect: working directory missing for $session: $worktree" >&2
    return 1
  fi

  if [[ "$dry_run" == true ]]; then
    echo "Would resurrect $mux session $session in $worktree:"
    echo "  $agent_cmd"
    return 0
  fi

  echo "Resurrecting $mux session $session ..."

  case "$mux" in
    tmux)
      tmux new-session -d -s "$session" -c "$worktree"
      tmux set-option -t "$session" @is_agent 1 2>/dev/null || true
      tmux rename-window -t "$session:1" "agent" 2>/dev/null || true
      tmux send-keys -t "${session}:1" \
        "$(printf '%q' "$agent_cmd"); \"$HOME/dotfiles/scripts/agent-registry.sh\" set-state \"$session\" exited" Enter
      ;;
    zellij)
      if [[ ! -f "$LAYOUT" ]]; then
        echo "resurrect: layout not found: $LAYOUT" >&2
        return 1
      fi
      export ZELLIJ_AGENT_CMD="$agent_cmd"
      (cd "$worktree" && zellij --layout "$LAYOUT" attach -b "$session")
      ;;
    *)
      echo "resurrect: unknown multiplexer '$mux'" >&2
      return 1
      ;;
  esac

  "$REGISTRY" set-state "$session" idle >/dev/null 2>&1 || true
}

# Resurrect a single registry record by session name.
resurrect() {
  local session="$1"
  local dry_run="${2:-false}"
  local file="$REGISTRY_DIR/${session}.json"

  [[ -f "$file" ]] || { echo "resurrect: no registry record for $session" >&2; return 1; }

  local mux worktree branch base agent_cmd state agent prompt
  mux="$(jq -r '.multiplexer // empty' "$file")"
  worktree="$(jq -r '.worktree // empty' "$file")"
  branch="$(jq -r '.branch // empty' "$file")"
  base="$(jq -r '.base // empty' "$file")"
  agent_cmd="$(jq -r '.agent_cmd // empty' "$file")"
  state="$(jq -r '.state // empty' "$file")"
  agent="$(jq -r '.agent // empty' "$file")"
  prompt="$(jq -r '.prompt // empty' "$file")"

  if [[ "$state" == "exited" ]]; then
    echo "resurrect: $session is marked exited; skipping (use agent-registry.sh set-state to clear)" >&2
    return 0
  fi

  if session_alive "$mux" "$session"; then
    echo "resurrect: $session is already alive ($mux)" >&2
    "$REGISTRY" set-state "$session" idle >/dev/null 2>&1 || true
    return 0
  fi

  # A worktree record has branch + base + worktree. Simple sessions lack base.
  if [[ -n "$branch" && -n "$base" && -n "$worktree" ]]; then
    resurrect_worktree "$session" "$mux" "$worktree" "$branch" "$base" "$agent_cmd" "$agent" "$prompt" "$dry_run"
  else
    resurrect_simple "$session" "$mux" "${worktree:-$HOME}" "$agent_cmd" "$dry_run"
  fi
}

main() {
  local cmd="${1:-}"
  local dry_run=false

  [[ -n "$cmd" ]] || usage
  shift || true

  for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && dry_run=true
  done

  case "$cmd" in
    list)
      list_dead
      ;;
    all)
      local count=0
      while IFS=$'\t' read -r session _rest; do
        [[ -n "$session" ]] || continue
        resurrect "$session" "$dry_run" || true
        count=$((count + 1))
      done < <(list_dead | cut -f1)
      echo "Scanned $count dead agent record(s)."
      ;;
    -h|--help)
      usage
      ;;
    *)
      resurrect "$cmd" "$dry_run"
      ;;
  esac
}

main "$@"
