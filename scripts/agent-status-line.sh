#!/usr/bin/env bash
# =============================================================================
# agent-status-line.sh — compact agent-state summary for the tmux status bar.
#
# Counts windows by @agent_state across ALL sessions — your agents live in
# separate sessions, which the per-session window list in the status bar can't
# see. Emits e.g. "⚡2 ✓1 " meaning 2 agents need you, 1 finished.
# Embedded #[...] styles are interpreted by tmux >= 3.2 in #() output.
# =============================================================================
command -v tmux >/dev/null 2>&1 || exit 0

waiting=0
done=0
while IFS= read -r s; do
  case "$s" in
    waiting) waiting=$((waiting + 1)) ;;
    done)    done=$((done + 1)) ;;
  esac
done < <(tmux list-windows -a -F '#{@agent_state}' 2>/dev/null)

out=""
[ "$waiting" -gt 0 ] && out="${out}#[fg=#f7768e,bold]⚡${waiting}#[default,fg=#565f89] "
[ "$done" -gt 0 ]    && out="${out}#[fg=#9ece6a]✓${done}#[default,fg=#565f89] "
printf '%s' "$out"
