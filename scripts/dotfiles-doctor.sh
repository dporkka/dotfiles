#!/usr/bin/env bash
# =============================================================================
# dotfiles-doctor.sh — diagnose the health of a dotfiles installation.
#
# Usage:
#   dotfiles-doctor.sh [--shell bash|zsh] [--fix]
#
# Checks shell/XDG symlinks, required binaries, tmux plugins, systemd units,
# Claude Code CLI, MCP blueprint connectivity, and SSH agent key loading.
# Exits non-zero if any critical check fails.
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_CHOICE=""
FIX=false

# Ensure common user-local tool paths are searchable so checks reflect the
# binaries a normal login shell would see.
PATH="$HOME/.local/bin:$HOME/.local/share/pnpm:$HOME/.cargo/bin:$HOME/go/bin:/usr/local/go/bin:$PATH"
export PATH

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_PASS=$'\033[32m'
  C_WARN=$'\033[33m'
  C_FAIL=$'\033[31m'
  C_INFO=$'\033[34m'
  C_RESET=$'\033[0m'
else
  C_PASS=""
  C_WARN=""
  C_FAIL=""
  C_INFO=""
  C_RESET=""
fi

pass()  { printf "  %s✓%s %s\n" "$C_PASS" "$C_RESET" "$*"; }
warn()  { printf "  %s⚠%s %s\n" "$C_WARN" "$C_RESET" "$*" >&2; }
fail()  { printf "  %s✗%s %s\n" "$C_FAIL" "$C_RESET" "$*" >&2; }
info()  { printf "  %sℹ%s %s\n" "$C_INFO" "$C_RESET" "$*"; }

usage() {
  sed -n '/^# Usage:/,/^# Exits non-zero/p' "$0" | sed 's/^# //; s/^#$//; /^$/d'
}

is_symlink() {
  [[ -L "$1" ]] && [[ -e "$1" ]]
}

has_binary() {
  command -v "$1" >/dev/null 2>&1
}

has_fd() {
  has_binary fd || has_binary fdfind
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shell=*) SHELL_CHOICE="${1#--shell=}"; shift ;;
    --shell)   SHELL_CHOICE="${2:-}"; shift 2 ;;
    --fix)     FIX=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown argument: $1"; exit 1 ;;
  esac
done

# -----------------------------------------------------------------------------
# Shell choice detection
# -----------------------------------------------------------------------------
if [[ -z "$SHELL_CHOICE" ]]; then
  if [[ -L "$HOME/.zshrc" && ! -L "$HOME/.bashrc" ]]; then
    SHELL_CHOICE="zsh"
  elif [[ -L "$HOME/.bashrc" && ! -L "$HOME/.zshrc" ]]; then
    SHELL_CHOICE="bash"
  elif [[ "${SHELL:-}" == */zsh ]]; then
    SHELL_CHOICE="zsh"
  else
    SHELL_CHOICE="bash"
  fi
fi
case "$SHELL_CHOICE" in
  bash|zsh) info "Checking health for shell: $SHELL_CHOICE" ;;
  *) fail "Invalid shell '$SHELL_CHOICE'. Use bash or zsh."; exit 1 ;;
esac

# -----------------------------------------------------------------------------
# Result tracking
# -----------------------------------------------------------------------------
declare -A CHECK_STATUS
declare -A CHECK_MESSAGE
declare -A CHECK_CRITICAL
CHECK_ORDER=()
critical_failures=0

register() {
  local name="$1" status="$2" message="$3" critical="${4:-true}"
  local is_new=false
  [[ -z "${CHECK_STATUS[$name]+x}" ]] && is_new=true
  CHECK_STATUS["$name"]="$status"
  CHECK_MESSAGE["$name"]="$message"
  CHECK_CRITICAL["$name"]="$critical"
  if [[ "$is_new" == true ]]; then
    CHECK_ORDER+=("$name")
  fi
  if [[ "$status" == "FAIL" && "$critical" == "true" ]]; then
    critical_failures=$((critical_failures + 1))
  fi
}

print_table() {
  echo ""
  printf "%-30s %-6s  %s\n" "Check" "Status" "Details"
  printf "%-30s %-6s  %s\n" "-----------------------------" "------" "----------------------------------------"
  for name in "${CHECK_ORDER[@]}"; do
    local status="${CHECK_STATUS[$name]}"
    local msg="${CHECK_MESSAGE[$name]}"
    local color=""
    case "$status" in
      PASS) color="$C_PASS" ;;
      WARN) color="$C_WARN" ;;
      FAIL) color="$C_FAIL" ;;
    esac
    printf "%-30s %s%-6s%s  %s\n" "$name" "$color" "$status" "$C_RESET" "$msg"
  done
  echo ""
}

# -----------------------------------------------------------------------------
# Checks
# -----------------------------------------------------------------------------
run_checks() {
  CHECK_STATUS=()
  CHECK_MESSAGE=()
  CHECK_CRITICAL=()
  CHECK_ORDER=()
  critical_failures=0

  # Shell config symlinks
  case "$SHELL_CHOICE" in
    bash)
      is_symlink "$HOME/.bashrc" \
        && register "shell:.bashrc" PASS "linked to repo" \
        || register "shell:.bashrc" FAIL "not symlinked to repo"
      if [[ -e "$DOTFILES_DIR/home/.bash_profile" ]]; then
        is_symlink "$HOME/.bash_profile" \
          && register "shell:.bash_profile" PASS "linked to repo" \
          || register "shell:.bash_profile" FAIL "not symlinked to repo"
      fi
      is_symlink "$HOME/.bashrc.d" \
        && register "shell:.bashrc.d" PASS "linked to repo" \
        || register "shell:.bashrc.d" FAIL "not symlinked to repo"
      ;;
    zsh)
      is_symlink "$HOME/.zshrc" \
        && register "shell:.zshrc" PASS "linked to repo" \
        || register "shell:.zshrc" FAIL "not symlinked to repo"
      ;;
  esac

  # XDG config symlinks
  for cfg in nvim tmux wezterm; do
    if is_symlink "$HOME/.config/$cfg"; then
      register "xdg:$cfg" PASS "linked ($(readlink "$HOME/.config/$cfg"))"
    else
      register "xdg:$cfg" FAIL "not symlinked"
    fi
  done

  # Required binaries
  for bin in git tmux nvim node npx uv rg fzf jq gh fd; do
    if [[ "$bin" == "fd" ]]; then
      if has_fd; then
        register "bin:fd" PASS "$(command -v fd 2>/dev/null || command -v fdfind 2>/dev/null)"
      else
        register "bin:fd" FAIL "fd (or fdfind) not found on PATH"
      fi
      continue
    fi
    if has_binary "$bin"; then
      register "bin:$bin" PASS "$(command -v "$bin")"
    else
      register "bin:$bin" FAIL "not found on PATH"
    fi
  done

  # tmux plugins
  local tpm_ok=true
  [[ -d "$HOME/.tmux/plugins/tpm" ]] || tpm_ok=false
  for plugin in tmux-sensible tmux-resurrect tmux-continuum tmux-yank; do
    [[ -d "$HOME/.tmux/plugins/$plugin" ]] || tpm_ok=false
  done
  if [[ "$tpm_ok" == true ]]; then
    register "tmux:plugins" PASS "TPM + core plugins present" false
  else
    register "tmux:plugins" WARN "TPM or core plugins missing" false
  fi

  # systemd user units
  if has_binary systemctl; then
    local missing_units=()
    local enabled_units=()
    for unit in tmux.service tmux-snapshot.timer; do
      if systemctl --user is-enabled "$unit" >/dev/null 2>&1; then
        enabled_units+=("$unit")
      else
        missing_units+=("$unit")
      fi
    done
    if [[ ${#missing_units[@]} -eq 0 ]]; then
      register "systemd:units" PASS "${enabled_units[*]}" false
    else
      register "systemd:units" WARN "not enabled: ${missing_units[*]}" false
    fi
  else
    register "systemd:units" WARN "systemctl not available" false
  fi

  # Claude Code CLI
  if has_binary claude; then
    register "tool:claude" PASS "$(command -v claude)" false
  else
    register "tool:claude" WARN "claude CLI not installed" false
  fi

  # MCP blueprint and connectivity
  local blueprint="$DOTFILES_DIR/config/mcp/servers.json"
  if [[ -f "$blueprint" ]]; then
    if has_binary claude; then
      local mcp_out=""
      mcp_out=$(timeout 10s claude mcp list 2>/dev/null || true)
      if [[ -n "$mcp_out" ]] && grep -qi "connected" <<< "$mcp_out"; then
        register "tool:mcp" PASS "blueprint present and servers connected" false
      elif [[ -n "$mcp_out" ]]; then
        register "tool:mcp" WARN "blueprint present but no connected servers" false
      else
        register "tool:mcp" WARN "blueprint present; could not verify claude mcp list" false
      fi
    else
      register "tool:mcp" WARN "blueprint present but claude CLI unavailable" false
    fi
  else
    register "tool:mcp" WARN "MCP blueprint missing: $blueprint" false
  fi

  # SSH agent keys
  if ssh-add -l >/dev/null 2>&1; then
    local key_count
    key_count=$(ssh-add -l 2>/dev/null | wc -l)
    register "ssh:agent" PASS "$key_count key(s) loaded" false
  else
    register "ssh:agent" WARN "no SSH keys loaded or agent unreachable" false
  fi
}

# -----------------------------------------------------------------------------
# Repairs
# -----------------------------------------------------------------------------
run_fixes() {
  info "Attempting common repairs..."

  backup_if_real() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
      local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
      mv "$target" "$backup"
      warn "Backed up $target -> $backup"
    elif [[ -L "$target" ]]; then
      rm "$target"
    fi
  }

  # Relink shell configs
  case "$SHELL_CHOICE" in
    bash)
      for target in .bashrc .bash_profile; do
        local src="$DOTFILES_DIR/home/$target"
        local dst="$HOME/$target"
        [[ -e "$src" ]] || continue
        backup_if_real "$dst"
        ln -sfn "$src" "$dst"
        pass "Relinked $dst"
      done
      backup_if_real "$HOME/.bashrc.d"
      ln -sfn "$DOTFILES_DIR/home/.bashrc.d" "$HOME/.bashrc.d"
      pass "Relinked ~/.bashrc.d"
      ;;
    zsh)
      backup_if_real "$HOME/.zshrc"
      ln -sfn "$DOTFILES_DIR/home/.zshrc" "$HOME/.zshrc"
      pass "Relinked ~/.zshrc"
      ;;
  esac

  # Relink XDG configs
  for cfg in nvim tmux; do
    local src="$DOTFILES_DIR/config/$cfg"
    local dst="$HOME/.config/$cfg"
    [[ -d "$src" ]] || continue
    backup_if_real "$dst"
    ln -sfn "$src" "$dst"
    pass "Relinked $dst"
  done

  # WezTerm config lives in its own repo
  local wezterm_src="$HOME/wezterm-config"
  local wezterm_dst="$HOME/.config/wezterm"
  if [[ -d "$wezterm_src" ]]; then
    backup_if_real "$wezterm_dst"
    ln -sfn "$wezterm_src" "$wezterm_dst"
    pass "Relinked ~/.config/wezterm"
  else
    warn "wezterm-config repo not found at $wezterm_src; skipping wezterm relink"
  fi

  # Re-enable systemd units
  if has_binary systemctl; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    if systemctl --user enable tmux.service tmux-snapshot.timer >/dev/null 2>&1; then
      pass "Enabled tmux systemd units"
    else
      warn "Could not enable tmux systemd units"
    fi
    if systemctl --user start tmux.service tmux-snapshot.timer >/dev/null 2>&1; then
      pass "Started tmux systemd units"
    else
      warn "Could not start tmux systemd units"
    fi
  fi

  # Install TPM + core plugins
  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    if git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" >/dev/null 2>&1; then
      pass "Installed TPM"
    else
      warn "Failed to clone TPM"
    fi
  fi
  for plugin in tmux-plugins/tmux-sensible tmux-plugins/tmux-resurrect tmux-plugins/tmux-continuum tmux-plugins/tmux-yank; do
    local name
    name=$(basename "$plugin")
    if [[ ! -d "$HOME/.tmux/plugins/$name" ]]; then
      if git clone "https://github.com/$plugin" "$HOME/.tmux/plugins/$name" >/dev/null 2>&1; then
        pass "Installed tmux plugin $name"
      else
        warn "Failed to install tmux plugin $name"
      fi
    fi
  done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
run_checks
print_table

if [[ "$FIX" == true ]]; then
  run_fixes
  echo ""
  info "Re-running checks after repairs..."
  run_checks
  print_table
fi

if [[ "$critical_failures" -gt 0 ]]; then
  fail "$critical_failures critical check(s) failed."
  exit 1
fi

pass "All critical checks passed."
exit 0
