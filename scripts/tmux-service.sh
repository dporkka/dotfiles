#!/usr/bin/env bash
# =============================================================================
# tmux-service.sh — manage the tmux user systemd service.
#
# Keeps a tmux server alive in the background so sessions survive terminal
# closure, logout, sleep, and reboot (via tmux-resurrect + tmux-continuum).
# The service runs a small "daemon" session as a process holder; real sessions
# are restored by tmux-continuum and dead agent sessions are resurrected from
# the agent registry snapshot.
#
# Usage:
#   tmux-service.sh install   # link unit files into ~/.config/systemd/user
#   tmux-service.sh enable    # start on login
#   tmux-service.sh start     # start now
#   tmux-service.sh stop      # stop now
#   tmux-service.sh restart   # restart now
#   tmux-service.sh status    # show systemd status
#   tmux-service.sh restore   # restore tmux sessions + reconcile + resurrect agents
#   tmux-service.sh daemon    # internal: run the daemon watchdog (systemd only)
# =============================================================================

set -euo pipefail

DOTS="${DOTS:-$HOME/dotfiles}"
SERVICE_NAME="tmux.service"
SERVICE_SRC="$DOTS/config/systemd/user/$SERVICE_NAME"
SERVICE_DST="$HOME/.config/systemd/user/$SERVICE_NAME"
TMUX_BIN="${TMUX_CMD:-$(command -v tmux)}"
DAEMON_SESSION="${TMUX_DAEMON_SESSION:-tmux-daemon}"
RESURRECT_RESTORE="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
RESURRECT_SAVE="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"

ensure_systemd() {
  command -v systemctl >/dev/null 2>&1 \
    || { echo "tmux-service: systemctl not found" >&2; exit 1; }
}

cmd_install() {
  [[ -f "$SERVICE_SRC" ]] \
    || { echo "tmux-service: unit file not found: $SERVICE_SRC" >&2; exit 1; }

  mkdir -p "$(dirname "$SERVICE_DST")"
  if [[ -L "$SERVICE_DST" ]]; then
    rm "$SERVICE_DST"
  elif [[ -e "$SERVICE_DST" ]]; then
    local backup="${SERVICE_DST}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$SERVICE_DST" "$backup"
    echo "tmux-service: backed up existing unit to $backup"
  fi
  ln -s "$SERVICE_SRC" "$SERVICE_DST"
  systemctl --user daemon-reload
  echo "tmux-service: installed $SERVICE_DST -> $SERVICE_SRC"
  echo "tmux-service: run 'tmux-service.sh enable && tmux-service.sh start' to activate"
}

cmd_enable() {
  ensure_systemd
  systemctl --user enable "$SERVICE_NAME"
}

cmd_start() {
  ensure_systemd
  systemctl --user start "$SERVICE_NAME"
}

cmd_stop() {
  ensure_systemd
  systemctl --user stop "$SERVICE_NAME"
}

cmd_restart() {
  ensure_systemd
  systemctl --user restart "$SERVICE_NAME"
}

cmd_status() {
  ensure_systemd
  systemctl --user status "$SERVICE_NAME"
}

ensure_dirs() {
  mkdir -p "$HOME/.local/state/tmux/resurrect" \
           "$HOME/.local/state/agents/registry" \
           "$HOME/.local/state/agents/snapshots"
}

server_alive() {
  "$TMUX_BIN" list-sessions >/dev/null 2>&1
}

daemon_session_exists() {
  "$TMUX_BIN" has-session -t "$DAEMON_SESSION" 2>/dev/null
}

start_daemon_session() {
  if ! daemon_session_exists; then
    "$TMUX_BIN" new-session -d -s "$DAEMON_SESSION" -c "$HOME"
  fi
}

stop_daemon_session() {
  "$TMUX_BIN" kill-session -t "$DAEMON_SESSION" >/dev/null 2>&1 || true
}

restore_sessions() {
  # Give continuum / the server a moment to settle.
  sleep 2
  if [[ -x "$RESURRECT_RESTORE" ]]; then
    "$RESURRECT_RESTORE" >/dev/null 2>&1 || true
  fi
  # Wait for restore to finish creating sessions.
  sleep 2
  # Reconcile registry state for restored sessions.
  "$DOTS/scripts/tmux-agent-persistence.sh" restore >/dev/null 2>&1 || true
  # Bring back agent sessions whose multiplexer session is still gone.
  "$DOTS/scripts/agent-resurrect.sh" all >/dev/null 2>&1 || true
}

save_sessions() {
  if [[ -x "$RESURRECT_SAVE" ]]; then
    "$TMUX_BIN" run-shell "$RESURRECT_SAVE" >/dev/null 2>&1 || true
  fi
  "$DOTS/scripts/agent-registry.sh" snapshot >/dev/null 2>&1 || true
  "$DOTS/scripts/tmux-agent-persistence.sh" save >/dev/null 2>&1 || true
}

STOPPING=0
SLEEP_PID=""

on_stop_signal() {
  STOPPING=1
  [[ -n "$SLEEP_PID" ]] && kill "$SLEEP_PID" 2>/dev/null || true
}

cmd_restore() {
  [[ -x "$TMUX_BIN" ]] \
    || { echo "tmux-service: tmux not found: $TMUX_BIN" >&2; exit 1; }

  ensure_dirs

  if ! server_alive; then
    start_daemon_session
  fi
  restore_sessions
}

cmd_daemon() {
  [[ -x "$TMUX_BIN" ]] \
    || { echo "tmux-service: tmux not found: $TMUX_BIN" >&2; exit 1; }

  ensure_dirs

  # If tmux is already running (e.g. user started it manually), just adopt it.
  if server_alive; then
    echo "tmux-service: tmux server already running; adopting"
  else
    start_daemon_session
    restore_sessions
  fi

  trap 'on_stop_signal' TERM INT

  # Keep the service alive and recreate the daemon session if the server exits.
  while [[ "$STOPPING" -eq 0 ]]; do
    sleep 30 &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null || true
    SLEEP_PID=""
    [[ "$STOPPING" -eq 0 ]] || break
    if ! server_alive; then
      start_daemon_session
      restore_sessions
    fi
  done

  save_sessions
  stop_daemon_session
}

cmd="${1:-}"
shift || true

case "$cmd" in
  install) cmd_install ;;
  enable)  cmd_enable ;;
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_restart ;;
  status)  cmd_status ;;
  restore) cmd_restore ;;
  daemon)  cmd_daemon ;;
  *)
    echo "Usage: tmux-service.sh {install|enable|start|stop|restart|status|restore|daemon}" >&2
    exit 2
    ;;
esac
