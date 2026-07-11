#!/usr/bin/env bash
# =============================================================================
# agent-diff-review.sh — auto-open DiffviewOpen in the editor pane when an
# agent finishes editing files.
#
# Designed to be called from:
#   1) agent-hook.sh        (automated — on every 'done' transition)
#   2) a tmux keybinding     (manual — run from any pane in the window)
#
# If there are changed files and an adjacent neovim pane is found, sends
# :DiffviewOpen to the editor. No-ops silently for the automated path;
# shows brief status messages for the manual path (--manual).
#
# Usage:
#   agent-diff-review.sh            # automated (quiet)
#   agent-diff-review.sh --manual   # manual keybinding (shows messages)
#
# Always exits 0 — must never block or fail the caller.
# =============================================================================

set -euo pipefail

manual=false
[[ "${1:-}" == "--manual" ]] && manual=true

# ---- Only run inside tmux ------------------------------------------------
[[ -n "${TMUX:-}" ]] || exit 0

# ---- Determine the current pane id ---------------------------------------
current_pane="${TMUX_PANE:-}"
if [[ -z "$current_pane" ]]; then
  current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
  [[ -n "$current_pane" ]] || exit 0
fi

# ---- Resolve the git worktree root ---------------------------------------
pane_path="$(tmux display-message -p -t "$current_pane" '#{pane_current_path}' 2>/dev/null || true)"
worktree="$(git -C "${pane_path:-$PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$worktree" ]] || exit 0

# ---- Find a neovim pane in the same window -------------------------------
find_nvim_pane() {
  local current="$1"
  local sess win
  sess="$(tmux display-message -p -t "$current" '#{session_name}' 2>/dev/null || true)"
  win="$(tmux display-message -p -t "$current" '#{window_index}' 2>/dev/null || true)"
  [[ -n "$sess" && -n "$win" ]] || return 1

  local candidate=""
  while read -r pid cmd; do
    [[ "$pid" == "$current" ]] && continue
    if echo "$cmd" | grep -qiE '^n?vim?$'; then
      candidate="$pid"
      break
    fi
  done < <(tmux list-panes -t "${sess}:${win}" -F '#{pane_id} #{pane_current_command}' 2>/dev/null)

  if [[ -n "$candidate" ]]; then
    echo "$candidate"
    return 0
  fi
  return 1
}

editor_pane="$(find_nvim_pane "$current_pane")"
if [[ -z "$editor_pane" ]]; then
  $manual && tmux display-message "agent-diff-review: no neovim pane in this window"
  exit 0
fi

# ---- Check whether tracked files changed --------------------------------
has_changes() {
  local repo="$1"
  # Diff against HEAD (staged + unstaged); fall back to plain diff for
  # repos with no HEAD yet (orphan branch, fresh init).
  git -C "$repo" diff HEAD --name-only 2>/dev/null | grep -q . && return 0
  git -C "$repo" diff --name-only 2>/dev/null | grep -q . && return 0
  return 1
}

if ! has_changes "$worktree"; then
  $manual && tmux display-message "agent-diff-review: no changed files"
  exit 0
fi

# ---- Send :DiffviewOpen to the editor pane ------------------------------
tmux send-keys -t "$editor_pane" ':DiffviewOpen' Enter
$manual && tmux display-message "agent-diff-review: opened DiffviewOpen"

exit 0
