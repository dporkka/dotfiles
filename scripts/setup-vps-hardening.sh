#!/usr/bin/env bash
# =============================================================================
# setup-vps-hardening.sh — idempotent VPS hardening and performance tuning.
#
# Safe to re-run. Designed for Ubuntu 22.04+ and Fedora 40+ on x86_64/aarch64.
#
# Usage:
#   bash ~/dotfiles/scripts/setup-vps-hardening.sh [options]
#
# Options:
#   --ssh-port N      Configure SSH to listen on port N (default: 22)
#   --no-fail2ban     Skip fail2ban installation/enablement
#   --dry-run         Print planned changes without applying them
#   --yes             Confirm the (dangerous) action when run as root
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Defaults
# -----------------------------------------------------------------------------
SSH_PORT=22
WITH_FAIL2BAN=true
DRY_RUN=false
YES=false

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
log()  { echo "==> $*"; }
warn() { echo "⚠ $*" >&2; }
fail() { echo "✗ $*" >&2; exit 1; }

run_or_dry() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "    [dry-run] $*"
  else
    "$@"
  fi
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-port=*) SSH_PORT="${1#--ssh-port=}"; shift ;;
    --ssh-port)   SSH_PORT="${2:-22}"; shift 2 ;;
    --no-fail2ban) WITH_FAIL2BAN=false; shift ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --yes)         YES=true; shift ;;
    --help|-h)
      sed -n '/^# Usage:/,/^#   --yes/p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

# Validate port
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [[ "$SSH_PORT" -lt 1 ]] || [[ "$SSH_PORT" -gt 65535 ]]; then
  fail "Invalid SSH port: $SSH_PORT"
fi

# -----------------------------------------------------------------------------
# Distro / package manager
# -----------------------------------------------------------------------------
if [[ -r /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
else
  fail "Cannot read /etc/os-release"
fi

case "${ID:-}" in
  ubuntu|debian) DISTRO="debian"; PKG_INSTALL="apt-get install -y"; PKG_UPDATE="apt-get update -qq" ;;
  fedora|rhel|centos|rocky|almalinux) DISTRO="fedora"; PKG_INSTALL="dnf install -y"; PKG_UPDATE="dnf check-update -q || true" ;;
  *) fail "Unsupported distro: ${ID:-unknown}. Use Ubuntu/Debian or Fedora/RHEL-family." ;;
esac

# -----------------------------------------------------------------------------
# Privilege detection
# -----------------------------------------------------------------------------
SUDO=""
if [[ "$EUID" -ne 0 ]]; then
  SUDO="sudo"
else
  log "Running as root."
  if [[ "$YES" != true ]]; then
    fail "Running as root can be dangerous. Re-run with --yes to confirm."
  fi
  warn "Proceeding as root because --yes was passed."
fi

# Ensure sudo is available when needed
if [[ -n "$SUDO" ]] && ! command -v sudo &>/dev/null; then
  fail "sudo is required but not installed."
fi

# -----------------------------------------------------------------------------
# Resource detection
# -----------------------------------------------------------------------------
RAM_BYTES=""
if [[ -r /proc/meminfo ]]; then
  RAM_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  RAM_BYTES=$((RAM_KB * 1024))
fi
if [[ -z "${RAM_BYTES:-}" ]] || [[ "$RAM_BYTES" -le 0 ]]; then
  warn "Could not detect RAM size; defaulting swap to 4 GB"
  RAM_BYTES=$((4 * 1024 * 1024 * 1024))
fi

# Cap swap at 16 GB
MAX_SWAP=$((16 * 1024 * 1024 * 1024))
if [[ "$RAM_BYTES" -gt "$MAX_SWAP" ]]; then
  SWAP_BYTES="$MAX_SWAP"
else
  SWAP_BYTES="$RAM_BYTES"
fi
SWAP_GB=$(( (SWAP_BYTES + 512 * 1024 * 1024) / (1024 * 1024 * 1024) ))

# -----------------------------------------------------------------------------
# 1. SWAP
# -----------------------------------------------------------------------------
SWAP_FILE="/swapfile"

ensure_swap() {
  local existing_swap_gb
  existing_swap_gb=$(free -b 2>/dev/null | awk '/^Swap:/ {printf "%.0f", $2 / (1024*1024*1024)}' || echo 0)

  if [[ "$existing_swap_gb" -ge "$SWAP_GB" ]]; then
    log "Swap already present and >= ${SWAP_GB} GB (${existing_swap_gb} GB); skipping swap creation."
    return 0
  fi

  log "Configuring ${SWAP_GB} GB swap file at ${SWAP_FILE}..."

  if [[ -f "$SWAP_FILE" ]]; then
    warn "Existing swap file found at ${SWAP_FILE}; it will be replaced."
    run_or_dry swapoff "$SWAP_FILE" || true
    run_or_dry rm -f "$SWAP_FILE"
  fi

  run_or_dry fallocate -l "${SWAP_GB}G" "$SWAP_FILE" || {
    warn "fallocate failed; falling back to dd (this may take a while)..."
    run_or_dry dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_GB * 1024)) status=progress
  }

  run_or_dry chmod 600 "$SWAP_FILE"
  run_or_dry mkswap "$SWAP_FILE"
  run_or_dry swapon "$SWAP_FILE"

  if ! grep -q "^${SWAP_FILE} " /etc/fstab 2>/dev/null; then
    run_or_dry cp /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
    run_or_dry sh -c "printf '%s\\n' '${SWAP_FILE} none swap sw 0 0' >> /etc/fstab"
  fi

  log "Swap enabled."
}

# -----------------------------------------------------------------------------
# 2. KERNEL TUNING
# -----------------------------------------------------------------------------
TUNING_CONF="/etc/sysctl.d/99-dotfiles-tuning.conf"

ensure_sysctl_tuning() {
  log "Applying kernel tuning (${TUNING_CONF})..."

  local desired
  desired=$(cat <<EOF
# Managed by dotfiles/scripts/setup-vps-hardening.sh
# Do not edit manually; changes will be reapplied on re-run.
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
)

  if [[ "$DRY_RUN" == true ]]; then
    echo "    [dry-run] would write ${TUNING_CONF}:"
    sed 's/^/        /' <<< "$desired"
    return 0
  fi

  if [[ -f "$TUNING_CONF" ]] && diff -q <(cat "$TUNING_CONF") <(printf '%s\n' "$desired") >/dev/null 2>&1; then
    log "Kernel tuning already configured."
  else
    printf '%s\n' "$desired" | $SUDO tee "$TUNING_CONF" >/dev/null
    $SUDO sysctl -p "$TUNING_CONF" >/dev/null || true
    log "Kernel tuning applied."
  fi
}

# -----------------------------------------------------------------------------
# 3. SSH HARDENING
# -----------------------------------------------------------------------------
SSHD_CONFIG="/etc/ssh/sshd_config"

set_sshd_option() {
  local key="$1" value="$2" file="${3:-$SSHD_CONFIG}"
  local escaped_key
  escaped_key=$(printf '%s' "$key" | sed 's/[][\\/.*+?{}|()^$]/\\&/g')

  if grep -qE "^\s*#?\s*${escaped_key}\s+" "$file" 2>/dev/null; then
    # Replace existing (commented or not) option
    $SUDO sed -i "s/^\s*#\?\s*\(${escaped_key}\)\s\+.*/\1 ${value}/" "$file"
  else
    # Append if absent
    echo "${key} ${value}" | $SUDO tee -a "$file" >/dev/null
  fi
}

ensure_ssh_hardening() {
  log "Hardening SSH configuration..."

  if [[ ! -f "$SSHD_CONFIG" ]]; then
    fail "SSH config not found at ${SSHD_CONFIG}"
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo "    [dry-run] would set Port ${SSH_PORT} in ${SSHD_CONFIG}"
    echo "    [dry-run] would set PasswordAuthentication no"
    echo "    [dry-run] would set PubkeyAuthentication yes"
    echo "    [dry-run] would set PermitRootLogin prohibit-password"
    echo "    [dry-run] would run: sshd -t && systemctl reload sshd/sshd"
    return 0
  fi

  # Backup original once
  if [[ ! -e "${SSHD_CONFIG}.orig" ]]; then
    $SUDO cp "$SSHD_CONFIG" "${SSHD_CONFIG}.orig"
  fi

  set_sshd_option "Port" "$SSH_PORT"
  set_sshd_option "PasswordAuthentication" "no"
  set_sshd_option "PubkeyAuthentication" "yes"
  set_sshd_option "PermitRootLogin" "prohibit-password"

  # Validate before reloading
  if $SUDO sshd -t; then
    if command -v systemctl &>/dev/null; then
      $SUDO systemctl reload sshd || $SUDO systemctl restart sshd
    elif command -v service &>/dev/null; then
      $SUDO service ssh reload || $SUDO service ssh restart || $SUDO service sshd restart
    else
      warn "Could not reload SSH service automatically; please reload manually."
    fi
    log "SSH hardened and service reloaded."
  else
    fail "sshd config test failed; aborting to avoid locking you out. Restore with: sudo cp ${SSHD_CONFIG}.orig ${SSHD_CONFIG}"
  fi
}

# -----------------------------------------------------------------------------
# 4. FAIL2BAN
# -----------------------------------------------------------------------------
ensure_fail2ban() {
  if [[ "$WITH_FAIL2BAN" != true ]]; then
    log "Skipping fail2ban (--no-fail2ban)."
    return 0
  fi

  log "Installing/enabling fail2ban..."

  if [[ "$DRY_RUN" == true ]]; then
    echo "    [dry-run] would install fail2ban via ${PKG_INSTALL}"
    echo "    [dry-run] would enable/start fail2ban service"
    return 0
  fi

  if ! command -v fail2ban-server &>/dev/null; then
    $SUDO $PKG_UPDATE >/dev/null 2>&1 || true
    $SUDO $PKG_INSTALL fail2ban >/dev/null 2>&1 || {
      warn "fail2ban installation failed; skipping."
      return 0
    }
  fi

  # Minimal sshd jail if no jail.local exists
  if [[ ! -f /etc/fail2ban/jail.local ]]; then
    $SUDO tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
backend = systemd
EOF
  fi

  if command -v systemctl &>/dev/null; then
    $SUDO systemctl enable --now fail2ban >/dev/null 2>&1 || warn "Could not enable/start fail2ban"
  fi

  log "fail2ban installed and enabled."
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
log "VPS hardening starting..."
log "Distro: ${ID:-unknown} | SSH port: ${SSH_PORT} | Dry run: ${DRY_RUN}"

ensure_swap
ensure_sysctl_tuning
ensure_ssh_hardening
ensure_fail2ban

log "VPS hardening complete."
if [[ "$DRY_RUN" == true ]]; then
  echo "No changes were applied (dry-run)."
fi
