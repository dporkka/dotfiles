#!/usr/bin/env bash
# =============================================================================
# dotfiles-info.sh — fast cached overview of the current workstation.
#
# Usage:
#   dotfiles-info.sh [--json] [--refresh]
#
# Caches results for 60 seconds. Use --refresh to bypass the cache.
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$HOME/.cache/dotfiles"

# Ensure common user-local tool paths are searchable so the overview reflects
# the binaries a normal login shell would see.
PATH="$HOME/.local/bin:$HOME/.local/share/pnpm:$HOME/.cargo/bin:$HOME/go/bin:/usr/local/go/bin:$PATH"
export PATH
CACHE_FILE="$CACHE_DIR/info.json"
TTL_SECONDS=60

JSON=false
REFRESH=false

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
usage() {
  sed -n '/^# Usage:/,/^# Caches results/p' "$0" | sed 's/^# //; s/^#$//; /^$/d'
}

log() { echo "==> $*" >&2; }

cache_mtime() {
  if stat -c %Y "$CACHE_FILE" >/dev/null 2>&1; then
    stat -c %Y "$CACHE_FILE"
  else
    stat -f %m "$CACHE_FILE"
  fi
}

cache_valid() {
  [[ -f "$CACHE_FILE" ]] || return 1
  local now mtime
  now=$(date +%s)
  mtime=$(cache_mtime)
  [[ $((now - mtime)) -lt $TTL_SECONDS ]]
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)    JSON=true; shift ;;
    --refresh) REFRESH=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# -----------------------------------------------------------------------------
# Cache hit
# -----------------------------------------------------------------------------
if [[ "$REFRESH" == false ]] && cache_valid; then
  if [[ "$JSON" == true ]]; then
    cat "$CACHE_FILE"
  else
    jq -r '
      "Host:       \(.hostname)",
      "OS:         \(.os)",
      "Shell:      \(.shell)",
      "User:       \(.user)",
      "",
      "tmux server: \(.tmux.server)",
      (if .tmux.server == "running" then ("Sessions:", (.tmux.sessions[] | "  - \(.)")) else empty end),
      "",
      "Agent status: \(.agent_status | if . == "" then "(none)" else . end)",
      "",
      "Recent dotfiles commits:",
      (.recent_commits[] | "  - \(.)"),
      "",
      "Quick commands:",
      (.quick_commands[] | "  \(.)")
    ' "$CACHE_FILE"
  fi
  exit 0
fi

# -----------------------------------------------------------------------------
# Gather data
# -----------------------------------------------------------------------------
log "Gathering workstation overview..."

hostname=$(hostname)
os=$(source /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Unknown")
shell="${SHELL:-$0}"
user="${USER:-$(id -un)}"

tmux_server="not running"
tmux_sessions="[]"
if command -v tmux >/dev/null 2>&1; then
  sessions_raw=$(tmux list-sessions -F '#S' 2>/dev/null || true)
  if [[ -n "$sessions_raw" ]]; then
    tmux_server="running"
    tmux_sessions=$(jq -R . <<< "$sessions_raw" | jq -s .)
  fi
fi

agent_status_raw=$("$DOTFILES_DIR/scripts/agent-status-line.sh" 2>/dev/null || true)
agent_status=$(sed 's/#\[[^]]*\]//g' <<< "$agent_status_raw")

recent_commits_raw=$(git -C "$DOTFILES_DIR" log --pretty=format:'%h %s' -3 2>/dev/null || true)
recent_commits=$(jq -R . <<< "$recent_commits_raw" | jq -s .)

# -----------------------------------------------------------------------------
# Build and cache JSON
# -----------------------------------------------------------------------------
mkdir -p "$CACHE_DIR"

jq -n \
  --arg hostname "$hostname" \
  --arg os "$os" \
  --arg shell "$shell" \
  --arg user "$user" \
  --arg tmux_server "$tmux_server" \
  --argjson tmux_sessions "$tmux_sessions" \
  --arg agent_status "$agent_status" \
  --argjson recent_commits "$recent_commits" \
  '{
    hostname: $hostname,
    os: $os,
    shell: $shell,
    user: $user,
    tmux: {
      server: $tmux_server,
      sessions: $tmux_sessions
    },
    agent_status: $agent_status,
    recent_commits: $recent_commits,
    quick_commands: [
      "dotfiles-doctor        diagnose dotfiles health",
      "dotfiles-info          show this overview",
      "work [name]            start/attach a tmux project session",
      "agent [task]           open Claude Code in a tmux window",
      "tmux attach -t <s>     attach to an existing tmux session",
      "tmux ls                list tmux sessions"
    ]
  }' > "$CACHE_FILE"

# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------
if [[ "$JSON" == true ]]; then
  cat "$CACHE_FILE"
else
  jq -r '
    "Host:       \(.hostname)",
    "OS:         \(.os)",
    "Shell:      \(.shell)",
    "User:       \(.user)",
    "",
    "tmux server: \(.tmux.server)",
    (if .tmux.server == "running" then ("Sessions:", (.tmux.sessions[] | "  - \(.)")) else empty end),
    "",
    "Agent status: \(.agent_status | if . == "" then "(none)" else . end)",
    "",
    "Recent dotfiles commits:",
    (.recent_commits[] | "  - \(.)"),
    "",
    "Quick commands:",
    (.quick_commands[] | "  \(.)")
  ' "$CACHE_FILE"
fi
