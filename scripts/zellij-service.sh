#!/usr/bin/env bash
# =============================================================================
# zellij-service.sh — manage the Zellij user systemd service.
#
# Keeps a Zellij server alive in the background so agent sessions survive
# terminal closure, logout, and reboot (via Zellij session serialization).
# The service runs a small "daemon" session as a process holder; real agent
# sessions are created with zellij-agent-session.sh / zellij-agent-worktree.sh.
#
# Usage:
#   zellij-service.sh install   # link unit file into ~/.config/systemd/user
#   zellij-service.sh enable    # start on login
#   zellij-service.sh start     # start now
#   zellij-service.sh stop      # stop now
#   zellij-service.sh restart   # restart now
#   zellij-service.sh status    # show systemd status
#   zellij-service.sh daemon    # internal: run the daemon watchdog (systemd only)
# =============================================================================

set -euo pipefail

DOTS="${DOTS:-$HOME/dotfiles}"
SERVICE_NAME="zellij.service"
SERVICE_SRC="$DOTS/config/systemd/user/$SERVICE_NAME"
SERVICE_DST="$HOME/.config/systemd/user/$SERVICE_NAME"
ZELLIJ="${ZELLIJ_CMD:-$HOME/.local/bin/zellij}"
LAYOUT="${ZELLIJ_DAEMON_LAYOUT:-$DOTS/config/zellij/layouts/daemon.kdl}"
SESSION="${ZELLIJ_DAEMON_SESSION:-zellij-daemon}"

ensure_systemd() {
  command -v systemctl >/dev/null 2>&1 \
    || { echo "zellij-service: systemctl not found" >&2; exit 1; }
}

cmd_install() {
  [[ -f "$SERVICE_SRC" ]] \
    || { echo "zellij-service: unit file not found: $SERVICE_SRC" >&2; exit 1; }

  mkdir -p "$(dirname "$SERVICE_DST")"
  if [[ -L "$SERVICE_DST" ]]; then
    rm "$SERVICE_DST"
  elif [[ -e "$SERVICE_DST" ]]; then
    local backup="${SERVICE_DST}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$SERVICE_DST" "$backup"
    echo "zellij-service: backed up existing unit to $backup"
  fi
  ln -s "$SERVICE_SRC" "$SERVICE_DST"
  systemctl --user daemon-reload
  echo "zellij-service: installed $SERVICE_DST -> $SERVICE_SRC"
  echo "zellij-service: run 'zellij-service.sh enable && zellij-service.sh start' to activate"
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

daemon_alive() {
  "$ZELLIJ" list-sessions --no-formatting >/dev/null 2>&1
}

daemon_session_exists() {
  "$ZELLIJ" list-sessions --no-formatting 2>/dev/null \
    | awk '{print $1}' \
    | grep -qxF "$SESSION"
}

start_daemon_session() {
  if ! daemon_session_exists; then
    "$ZELLIJ" --layout "$LAYOUT" attach -b "$SESSION" >/dev/null 2>&1 || true
  fi
}

stop_daemon_session() {
  # delete-session --force fully removes the active holder; kill-session only
  # marks it EXITED and keeps it resurrectable, which is not what we want for
  # a daemon holder.
  "$ZELLIJ" delete-session --force "$SESSION" >/dev/null 2>&1 || true
}

STOPPING=0
SLEEP_PID=""

on_stop_signal() {
  STOPPING=1
  [[ -n "$SLEEP_PID" ]] && kill "$SLEEP_PID" 2>/dev/null || true
}

cmd_daemon() {
  [[ -x "$ZELLIJ" ]] \
    || { echo "zellij-service: zellij not found: $ZELLIJ" >&2; exit 1; }
  [[ -f "$LAYOUT" ]] \
    || { echo "zellij-service: layout not found: $LAYOUT" >&2; exit 1; }

  mkdir -p "$HOME/.local/share/zellij" "$HOME/.local/state/agents/registry"

  # On SIGTERM/SIGINT, set the stop flag and interrupt the sleeping child.
  # The loop then exits so systemd can clean up the service cgroup.
  trap 'on_stop_signal' TERM INT

  start_daemon_session

  # Keep the service alive and recreate the daemon session if the server
  # ever exits (e.g. crash, OOM kill). Sleep in a background child so the
  # main shell handles signals immediately instead of waiting for sleep(1).
  while [[ "$STOPPING" -eq 0 ]]; do
    sleep 30 &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null || true
    SLEEP_PID=""
    [[ "$STOPPING" -eq 0 ]] || break
    if ! daemon_alive; then
      start_daemon_session
    fi
  done

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
  daemon)  cmd_daemon ;;
  *)
    echo "Usage: zellij-service.sh {install|enable|start|stop|restart|status|daemon}" >&2
    exit 2
    ;;
esac
