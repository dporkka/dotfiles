#!/usr/bin/env bash
# =============================================================================
# setup-workstation.sh — one-shot developer environment bundle.
#
# This script is the single entrypoint for applying all of my computer
# optimizations to a fresh local machine, laptop, or VPS. It clones/updates the
# relevant repos and runs each installer in the right order.
#
# Usage:
#   bash <(curl -sS https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/setup-workstation.sh)
#
# Or, after cloning:
#   bash ~/dotfiles/scripts/setup-workstation.sh [options]
#
# Options:
#   --mode desktop|server    desktop = local GUI/WSL; server = headless VPS
#   --shell bash|zsh         default login shell
#   --with-runtimes          also run dev-setup (Node/Go/Python/Rust + LSPs)
#   --with-hardening         run setup-vps-hardening.sh (server mode only)
#   --yes                    skip interactive prompts; default to bash/safe choices
#   --skip-preflight         skip preflight system checks
#   --force                  ignore checkpoint state and rerun all phases
#   --help                   show this help
#
# The script auto-detects mode when not provided:
#   - WSL -> desktop
#   - GNOME desktop session -> desktop
#   - otherwise -> server
# =============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.local/state/dotfiles/install-state.json"

REPO_DOTFILES="https://github.com/dporkka/dotfiles.git"
REPO_WEZTERM="https://github.com/dporkka/command-tower-wezterm.git"
REPO_KEYBOARD="https://github.com/dporkka/linux-keyboard-setup.git"
REPO_DEVSETUP="https://github.com/dporkka/dev-setup.git"

MODE=""
SHELL_CHOICE=""
WITH_RUNTIMES=false
WITH_HARDENING=false
YES=false
SKIP_PREFLIGHT=false
FORCE=false

declare -a COMPLETED_ARR=()

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
log()  { echo "[$(date +%H:%M:%S)] ==> $*"; }
warn() { echo "⚠ $*" >&2; }
fail() { echo "✗ $*" >&2; exit 1; }

usage() {
  sed -n '/^# Usage:/,/^# The script auto-detects/p' "$0" | sed 's/^# //'
}

clone_or_pull() {
  local url="$1" dir="$2"
  if [[ -d "$dir/.git" ]]; then
    log "Pulling $dir ..."
    git -C "$dir" pull --ff-only || warn "Could not pull $dir"
  else
    log "Cloning $url -> $dir ..."
    git clone "$url" "$dir"
  fi
}

backup_then_link() {
  local src="$1" dst="$2"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "${dst}.bak.${ts}"
    warn "Backed up $dst -> ${dst}.bak.${ts}"
  fi
  ln -sfn "$src" "$dst"
  log "Linked $dst -> $src"
}

# ------------------------------------------------------------------------------
# Checkpoint / resume state
# ------------------------------------------------------------------------------
write_state() {
  local current="$1" status="$2"
  local list="" first=true
  for p in "${COMPLETED_ARR[@]}"; do
    if [[ "$first" == true ]]; then first=false; else list+=","; fi
    list+=$'\n    '"\"$p\""
  done
  mkdir -p "$(dirname "$STATE_FILE")"
  cat > "$STATE_FILE" <<EOF
{
  "last_run": "$(date -Iseconds)",
  "mode": "$MODE",
  "shell": "$SHELL_CHOICE",
  "current_phase": "$current",
  "status": "$status",
  "completed": [$list
  ]
}
EOF
}

phase_in_list() {
  local phase="$1"
  for p in "${COMPLETED_ARR[@]}"; do
    [[ "$p" == "$phase" ]] && return 0
  done
  return 1
}

add_completed() {
  local phase="$1"
  phase_in_list "$phase" && return
  COMPLETED_ARR+=("$phase")
}

run_phase() {
  local phase="$1"
  shift
  if phase_in_list "$phase"; then
    log "Phase '$phase' already completed; skipping (use --force to rerun)."
    return 0
  fi
  write_state "$phase" "in_progress"
  "$@" || fail "Phase '$phase' failed."
  add_completed "$phase"
  write_state "$phase" "done"
}

load_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    return 0
  fi
  if [[ "$FORCE" == true ]]; then
    log "--force set; ignoring existing checkpoint state."
    COMPLETED_ARR=()
    return 0
  fi

  local saved_mode="" saved_shell=""
  if command -v python3 &>/dev/null; then
    saved_mode="$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('mode',''))" 2>/dev/null || true)"
    saved_shell="$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('shell',''))" 2>/dev/null || true)"
    mapfile -t COMPLETED_ARR < <(python3 -c "import json; print('\n'.join(json.load(open('$STATE_FILE')).get('completed',[])))" 2>/dev/null || true)
  else
    saved_mode="$(sed -n 's/.*"mode": *"\([^"]*\)".*/\1/p' "$STATE_FILE" 2>/dev/null | head -1 || true)"
    saved_shell="$(sed -n 's/.*"shell": *"\([^"]*\)".*/\1/p' "$STATE_FILE" 2>/dev/null | head -1 || true)"
    mapfile -t COMPLETED_ARR < <(sed -n '/"completed": *\[/,/\]/p' "$STATE_FILE" 2>/dev/null | grep -oP '"\K[^"]+(?=")' || true)
  fi

  # Python/sed may produce an empty first element for an empty completed array.
  local cleaned=()
  for p in "${COMPLETED_ARR[@]}"; do
    [[ -n "$p" ]] && cleaned+=("$p")
  done
  COMPLETED_ARR=("${cleaned[@]}")

  if [[ -n "$saved_mode" && "$saved_mode" != "$MODE" ]]; then
    warn "Checkpoint mode ($saved_mode) differs from current mode ($MODE); resetting checkpoint state."
    COMPLETED_ARR=()
    return 0
  fi
  if [[ -n "$saved_shell" && "$saved_shell" != "$SHELL_CHOICE" ]]; then
    warn "Checkpoint shell ($saved_shell) differs from current shell ($SHELL_CHOICE); resetting checkpoint state."
    COMPLETED_ARR=()
    return 0
  fi

  log "Resuming from checkpoint state ($(date -Iseconds -r "$STATE_FILE" 2>/dev/null || echo previous run))."
}

# ------------------------------------------------------------------------------
# Preflight
# ------------------------------------------------------------------------------
run_preflight() {
  if [[ "$SKIP_PREFLIGHT" == true ]]; then
    log "Skipping preflight checks (--skip-preflight)."
    return 0
  fi

  local preflight="$SCRIPT_DIR/preflight.sh"
  if [[ -x "$preflight" ]]; then
    bash "$preflight" || fail "Preflight checks failed. Fix issues or use --skip-preflight."
    return 0
  fi

  if command -v curl &>/dev/null; then
    log "Preflight script not found locally; fetching from GitHub..."
    bash <(curl -fsSL --max-time 30 "https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/preflight.sh") \
      || fail "Preflight checks failed. Fix issues or use --skip-preflight."
    return 0
  fi

  warn "Preflight script not available and curl is missing; continuing without preflight."
}

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --mode)   MODE="${2:-}"; shift 2 ;;
    --shell=*) SHELL_CHOICE="${1#--shell=}"; shift ;;
    --shell)   SHELL_CHOICE="${2:-}"; shift 2 ;;
    --with-runtimes) WITH_RUNTIMES=true; shift ;;
    --with-hardening) WITH_HARDENING=true; shift ;;
    --yes) YES=true; shift ;;
    --skip-preflight) SKIP_PREFLIGHT=true; shift ;;
    --force) FORCE=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

# ------------------------------------------------------------------------------
# Mode auto-detection
# ------------------------------------------------------------------------------
if [[ -z "$MODE" ]]; then
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    MODE="desktop"
  elif [[ -n "${DESKTOP_SESSION:-}" ]] || pgrep -x gnome-shell &>/dev/null || pgrep -x sway &>/dev/null; then
    MODE="desktop"
  else
    MODE="server"
  fi
fi
case "$MODE" in
  desktop|server) ;;
  *) fail "Invalid mode '$MODE'. Use desktop or server." ;;
esac
log "Mode: $MODE"

# ------------------------------------------------------------------------------
# Shell selection
# ------------------------------------------------------------------------------
if [[ -z "$SHELL_CHOICE" ]]; then
  if [[ "$YES" == true ]]; then
    SHELL_CHOICE="bash"
    log "--yes: defaulting shell to bash"
  elif [[ -t 0 ]]; then
    echo ""
    echo "Which shell should be the default/login shell?"
    PS3="Select shell: "
    select opt in bash zsh; do
      case "$opt" in
        bash|zsh) SHELL_CHOICE="$opt"; break ;;
        *) echo "Invalid choice. Please enter 1 (bash) or 2 (zsh)." ;;
      esac
    done
  else
    log "No --shell provided and stdin is not a TTY; defaulting to bash."
    SHELL_CHOICE="bash"
  fi
fi
case "$SHELL_CHOICE" in
  bash|zsh) ;;
  *) fail "Invalid shell '$SHELL_CHOICE'. Use bash or zsh." ;;
esac
log "Shell: $SHELL_CHOICE"

# ------------------------------------------------------------------------------
# Pre-flight / early requirements
# ------------------------------------------------------------------------------
load_state
write_state "" "in_progress"
run_preflight

if [[ "$SKIP_PREFLIGHT" == true ]]; then
  command -v git &>/dev/null || fail "git is required"
  command -v curl &>/dev/null || fail "curl is required"
fi
sudo -n true 2>/dev/null || warn "sudo access may be required for package installs"

# dev-setup is zsh-oriented; avoid polluting versioned bash configs.
if [[ "$WITH_RUNTIMES" == true && "$SHELL_CHOICE" != "zsh" ]]; then
  fail "--with-runtimes currently requires --shell zsh (dev-setup appends to .zshrc)"
fi

if [[ "$WITH_HARDENING" == true && "$MODE" != "server" ]]; then
  warn "--with-hardening is only applied in server mode; ignoring."
  WITH_HARDENING=false
fi

# ------------------------------------------------------------------------------
# Phases
# ------------------------------------------------------------------------------
phase_clone_repos() {
  log "Cloning / updating repositories..."
  clone_or_pull "$REPO_DOTFILES" "$HOME/dotfiles"
  clone_or_pull "$REPO_WEZTERM" "$HOME/wezterm-config"
  clone_or_pull "$REPO_KEYBOARD" "$HOME/linux-keyboard-setup"
  if [[ "$WITH_RUNTIMES" == true ]]; then
    clone_or_pull "$REPO_DEVSETUP" "$HOME/dev-setup"
  fi
}

phase_bootstrap() {
  log "Running dotfiles bootstrap..."
  export MODE
  export SHELL_CHOICE
  bash "$HOME/dotfiles/scripts/bootstrap.sh"
}

phase_link_wezterm() {
  log "Linking WezTerm config..."
  backup_then_link "$HOME/wezterm-config" "$HOME/.config/wezterm"
}

phase_desktop_extras() {
  if [[ "$MODE" != "desktop" ]]; then return 0; fi
  log "Applying Linux keyboard setup..."
  bash "$HOME/linux-keyboard-setup/apply.sh" || warn "linux-keyboard-setup failed"
}

phase_server_extras() {
  if [[ "$MODE" != "server" ]]; then return 0; fi
  log "Setting up EternalTerminal server..."
  bash "$HOME/dotfiles/scripts/setup-et-server.sh" || warn "ET server setup failed"
  log "Mosh server setup is available at ~/dotfiles/scripts/setup-mosh-server.sh"
}

phase_hardening() {
  if [[ "$MODE" != "server" || "$WITH_HARDENING" != true ]]; then return 0; fi
  local hardening_script="$SCRIPT_DIR/setup-vps-hardening.sh"
  if [[ ! -f "$hardening_script" ]]; then
    warn "setup-vps-hardening.sh not found; skipping hardening."
    return 0
  fi
  log "Running VPS hardening..."
  bash "$hardening_script" || warn "VPS hardening failed"
}

phase_runtimes() {
  if [[ "$WITH_RUNTIMES" != true ]]; then return 0; fi
  log "Running dev-setup (language runtimes + LSPs)..."
  bash "$HOME/dev-setup/bootstrap-vps.sh" || warn "dev-setup failed"
}

run_phase "clone-repos" phase_clone_repos
run_phase "bootstrap" phase_bootstrap
run_phase "link-wezterm" phase_link_wezterm
run_phase "desktop-extras" phase_desktop_extras
run_phase "server-extras" phase_server_extras
if [[ "$WITH_HARDENING" == true ]]; then
  run_phase "hardening" phase_hardening
fi
if [[ "$WITH_RUNTIMES" == true ]]; then
  run_phase "runtimes" phase_runtimes
fi

write_state "" "done"

# ------------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------------
echo ""
echo "=============================================================="
echo "Workstation setup complete!"
echo "=============================================================="
echo ""
echo "Mode:    $MODE"
echo "Shell:   $SHELL_CHOICE"
echo "Repos:   ~/dotfiles, ~/wezterm-config, ~/linux-keyboard-setup"
[[ "$WITH_RUNTIMES" == true ]] && echo "         ~/dev-setup"
[[ "$WITH_HARDENING" == true ]] && echo "         VPS hardening applied"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal / log out and back in."
echo "  2. Inside tmux, install plugins: prefix + I  (default prefix is C-a)"
echo "  3. Run 'gh auth login' if you use GitHub CLI."
echo "  4. Add secrets to ~/.config/zsh/secrets.zsh"
echo ""
echo "Connect to a remote server with:"
echo "  et user@host -c 'tmux new-session -A -s main'"
echo "Or use WezTerm: LEADER + e  /  LEADER + E"
