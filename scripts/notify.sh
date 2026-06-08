#!/usr/bin/env bash
# =============================================================================
# notify.sh — best-effort desktop notification, WSL2-aware.
# Layers (all best-effort, never fail the caller):
#   1. terminal bell  (tmux monitor-bell flags the window — see tmux.conf)
#   2. tmux status message (if inside tmux)
#   3. notify-send     (if a Linux notification daemon is present)
#   4. Windows toast   (WSL2: a balloon via PowerShell NotifyIcon, no extra modules)
#
# Usage: notify.sh "title" ["message"]
#   used by agent-session.sh to ping you when a background agent finishes.
# =============================================================================

title="${1:-Done}"
msg="${2:-}"

printf '\a' 2>/dev/null || true

if [[ -n "${TMUX:-}" ]]; then
  tmux display-message "#[fg=#9ece6a]🔔 ${title}#[default] ${msg}" 2>/dev/null || true
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "$title" "$msg" 2>/dev/null || true
fi

if grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
  # Sanitize single quotes so they don't break the PowerShell string literal.
  t="${title//\'/\'\'}"
  m="${msg//\'/\'\'}"
  powershell.exe -NoProfile -NonInteractive -Command "
    \$ErrorActionPreference='SilentlyContinue';
    Add-Type -AssemblyName System.Windows.Forms;
    Add-Type -AssemblyName System.Drawing;
    \$n = New-Object System.Windows.Forms.NotifyIcon;
    \$n.Icon = [System.Drawing.SystemIcons]::Information;
    \$n.Visible = \$true;
    \$n.ShowBalloonTip(5000, '${t}', '${m}', [System.Windows.Forms.ToolTipIcon]::Info);
    Start-Sleep -Milliseconds 6000;
    \$n.Dispose()
  " >/dev/null 2>&1 &
fi

exit 0
