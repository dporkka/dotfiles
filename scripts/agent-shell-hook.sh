#!/usr/bin/env bash
# =============================================================================
# agent-shell-hook.sh — shell integration for the unified agent registry.
#
# Designed to be called from zsh precmd/chpwd (and bash PROMPT_COMMAND if desired).
# It keeps registry records in sync with the shell's actual context and can
# resurrect a dead agent session when you cd back into its worktree.
#
# Usage in ~/.zshrc:
#   agent_precmd() { $HOME/dotfiles/scripts/agent-shell-hook.sh; }
#   agent_chpwd()  { $HOME/dotfiles/scripts/agent-shell-hook.sh; }
#   precmd_functions+=(agent_precmd)
#   chpwd_functions+=(agent_chpwd)
#
# Environment:
#   AGENT_AUTO_RESURRECT=true   # auto-resurrect dead worktree sessions on cd
#   AGENT_NO_REGISTRY_UPDATE=1  # skip registry updates (fast mode)
#
# Always exits 0 — a shell hook must never block or spam errors.
# =============================================================================

set -euo pipefail

REGISTRY="${HOME}/dotfiles/scripts/agent-registry.sh"
SNAPSHOT_DIR="${AGENT_SNAPSHOT_DIR:-$HOME/.local/state/agents/snapshots}"

# Nothing to do if the registry tooling is missing.
[[ -x "$REGISTRY" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Determine current multiplexer session name, if any.
multiplexer=""
session_name=""
if [[ -n "${TMUX:-}" ]]; then
  multiplexer="tmux"
  session_name="$(tmux display-message -p '#S' 2>/dev/null || true)"
elif [[ -n "${ZELLIJ_SESSION_NAME:-}" ]]; then
  multiplexer="zellij"
  session_name="$ZELLIJ_SESSION_NAME"
fi

# Best-effort current git branch inside the worktree.
current_branch() {
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git branch --show-current 2>/dev/null || true
  fi
}

# Update the registry record for the current multiplexer session.
update_session_record() {
  [[ -n "$session_name" && -n "$multiplexer" ]] || return 0
  [[ "${AGENT_NO_REGISTRY_UPDATE:-0}" != "1" ]] || return 0

  local record_file="$HOME/.local/state/agents/registry/${session_name}.json"
  [[ -f "$record_file" ]] || return 0

  local branch worktree
  branch="$(current_branch)"
  worktree="$PWD"

  # Only touch the registry when something meaningful changed.
  local old_branch old_worktree
  old_branch="$(jq -r '.branch // empty' "$record_file" 2>/dev/null || true)"
  old_worktree="$(jq -r '.worktree // empty' "$record_file" 2>/dev/null || true)"

  [[ "$branch" != "$old_branch" ]] || [[ "$worktree" != "$old_worktree" ]] || return 0

  [[ -n "$branch" ]] && "$REGISTRY" set "$session_name" branch "$branch" >/dev/null 2>&1 || true
  "$REGISTRY" set "$session_name" worktree "$worktree" >/dev/null 2>&1 || true
}

# If the current directory is a known agent worktree whose session is dead, offer
# to resurrect it. Auto-resurrect only when AGENT_AUTO_RESURRECT=true.
maybe_resurrect_worktree() {
  [[ -n "$PWD" ]] || return 0
  [[ -d "$SNAPSHOT_DIR" ]] || return 0

  local latest
  latest="$(ls -t "$SNAPSHOT_DIR"/*.json 2>/dev/null | head -n1 || true)"
  [[ -n "$latest" && -f "$latest" ]] || return 0

  # Find a snapshot record whose worktree matches the current directory.
  # Use first() so a reused worktree only resurrects the most recent match.
  local match
  match="$(jq -r --arg pwd "$PWD" '[.[] | select(.worktree == $pwd)] | first | [.session, .multiplexer, .state, .branch, .base, .agent, .prompt, .agent_cmd] | @tsv' "$latest" 2>/dev/null || true)"
  [[ -n "$match" ]] || return 0

  local snap_session snap_mux snap_branch snap_base snap_agent snap_prompt snap_agent_cmd
  snap_session="$(printf '%s' "$match" | cut -f1)"
  snap_mux="$(printf '%s' "$match" | cut -f2)"
  snap_branch="$(printf '%s' "$match" | cut -f4)"
  snap_base="$(printf '%s' "$match" | cut -f5)"
  snap_agent="$(printf '%s' "$match" | cut -f6)"
  snap_prompt="$(printf '%s' "$match" | cut -f7)"
  snap_agent_cmd="$(printf '%s' "$match" | cut -f8)"
  [[ -n "$snap_session" && -n "$snap_mux" ]] || return 0

  # Fall back to parsing agent_cmd for older snapshots without agent/prompt fields.
  if [[ -z "$snap_agent" && -n "$snap_agent_cmd" ]]; then
    snap_agent="${snap_agent_cmd%% *}"
    if [[ "$snap_agent_cmd" == *" "* ]]; then
      snap_prompt="${snap_agent_cmd#* }"
    fi
  fi
  [[ -n "$snap_agent" ]] || snap_agent="claude"

  # Check whether the session is still alive.
  case "$snap_mux" in
    tmux)
      tmux has-session -t "$snap_session" 2>/dev/null && return 0
      ;;
    zellij)
      zellij list-sessions --no-formatting 2>/dev/null | awk '{print $1}' | grep -qxF "$snap_session" && return 0
      ;;
    *) return 0 ;;
  esac

  if [[ "${AGENT_AUTO_RESURRECT:-false}" == "true" ]]; then
    echo "[agent] resurrecting $snap_mux session '$snap_session'..." >&2
    case "$snap_mux" in
      tmux)
        if [[ -n "$snap_branch" && -n "$snap_base" ]]; then
          if [[ -n "$snap_prompt" ]]; then
            "$HOME/dotfiles/scripts/agent-worktree.sh" "$snap_branch" --base "$snap_base" --agent "${snap_agent:-claude}" "$snap_prompt" >/dev/null 2>&1 || true
          else
            "$HOME/dotfiles/scripts/agent-worktree.sh" "$snap_branch" --base "$snap_base" --agent "${snap_agent:-claude}" >/dev/null 2>&1 || true
          fi
        else
          "$HOME/dotfiles/scripts/agent-session.sh" "$snap_session" "${snap_agent:-claude}"${snap_prompt:+ }$snap_prompt >/dev/null 2>&1 || true
        fi
        ;;
      zellij)
        if [[ -n "$snap_branch" && -n "$snap_base" ]]; then
          if [[ -n "$snap_prompt" ]]; then
            "$HOME/dotfiles/scripts/zellij-agent-worktree.sh" "$snap_branch" --base "$snap_base" --agent "${snap_agent:-claude}" "$snap_prompt" >/dev/null 2>&1 || true
          else
            "$HOME/dotfiles/scripts/zellij-agent-worktree.sh" "$snap_branch" --base "$snap_base" --agent "${snap_agent:-claude}" >/dev/null 2>&1 || true
          fi
        else
          "$HOME/dotfiles/scripts/zellij-agent-session.sh" "$snap_session" "${snap_agent:-claude}"${snap_prompt:+ }$snap_prompt >/dev/null 2>&1 || true
        fi
        ;;
    esac
  else
    # Print a quiet hint so the user knows they can resurrect.
    echo "[agent] dead session '$snap_session' ($snap_mux) available; set AGENT_AUTO_RESURRECT=true to auto-resurrect" >&2
  fi
}

update_session_record
maybe_resurrect_worktree

exit 0
