#!/usr/bin/env bash
# =============================================================================
# agent-hook.sh — called by Claude Code hooks to surface agent state in tmux.
#
# Wire in ~/.claude/settings.json:
#   UserPromptSubmit -> agent-hook.sh working    (you just handed it a task)
#   Notification     -> agent-hook.sh waiting     (it needs input / permission)
#   Stop             -> agent-hook.sh done         (it finished a turn)
#
# Effect:
#   * sets a per-window tmux user option @agent_state, read by the status bar
#     (window glyph + global ⚡/✓ counts) and by agent-dashboard.sh
#   * fires notify.sh (bell + tmux message + WSL toast)
#
# 'done' only toasts when you are NOT already looking at that pane, so active
# pairing with one agent stays quiet while background agents still ping you.
# Always exits 0 — a hook must never block or fail the agent.
# =============================================================================

state="${1:-done}"

# Drain the hook's JSON payload on stdin so Claude Code never blocks on us.
cat >/dev/null 2>&1 || true

label="agent"
focused=0
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
  tmux set-option -w -t "$TMUX_PANE" @agent_state "$state" 2>/dev/null || true
  label="$(tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null || echo agent)"
  # focused = a client is attached AND this is the active pane of the active window
  focused="$(tmux display-message -p -t "$TMUX_PANE" \
    '#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}}' 2>/dev/null || echo 0)"
fi

ping() { "$HOME/dotfiles/scripts/notify.sh" "$1" "$2" >/dev/null 2>&1 || true; }

case "$state" in
  waiting) ping "🟡 ${label} needs you" "Claude is waiting for input" ;;
  done)    [[ "$focused" != "1" ]] && ping "✅ ${label} finished" "Claude completed a turn" ;;
  working) : ;;  # clear the marker only; no ping while you're actively driving
esac

exit 0
