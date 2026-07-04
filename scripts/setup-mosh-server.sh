#!/usr/bin/env bash
# setup-mosh-server.sh — Idempotent Mosh server setup for Fedora/RHEL.
#
# Run on the remote server (copy there first, e.g. with scp):
#   scp ~/dotfiles/scripts/setup-mosh-server.sh remotehost:/tmp/
#   ssh remotehost 'bash /tmp/setup-mosh-server.sh'
#
# This script installs the `mosh` package (which provides mosh-server), opens the
# default Mosh UDP port range (60000-61000) in firewalld, and verifies that
# mosh-server is available.

set -euo pipefail

MOSH_PORT_START=60000
MOSH_PORT_END=61000

# ------------------------------------------------------------------------------
# Distro check
# ------------------------------------------------------------------------------
if [ -r /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
else
    echo "ERROR: cannot read /etc/os-release" >&2
    exit 1
fi

case "${ID:-}" in
    fedora|rhel|centos|rocky|almalinux)
        ;;
    *)
        echo "ERROR: unsupported distro: ${ID:-unknown}. This script supports Fedora/RHEL-family." >&2
        exit 1
        ;;
esac

# ------------------------------------------------------------------------------
# Privilege detection (use sudo only when not root)
# ------------------------------------------------------------------------------
SUDO=""
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
fi

# ------------------------------------------------------------------------------
# Install Mosh
# ------------------------------------------------------------------------------
echo "==> Installing Mosh..."
if ! rpm -q mosh >/dev/null 2>&1; then
    $SUDO dnf install -y mosh
else
    echo "    mosh is already installed"
fi

# ------------------------------------------------------------------------------
# Open firewall UDP range
# ------------------------------------------------------------------------------
echo "==> Configuring firewall (UDP ${MOSH_PORT_START}-${MOSH_PORT_END})..."
if command -v firewall-cmd >/dev/null 2>&1; then
    if systemctl is-active --quiet firewalld; then
        $SUDO firewall-cmd --permanent --add-port="${MOSH_PORT_START}-${MOSH_PORT_END}/udp"
        $SUDO firewall-cmd --reload
        echo "    opened UDP ${MOSH_PORT_START}-${MOSH_PORT_END} in firewalld"
    else
        echo "    WARNING: firewalld is installed but not running; skipping firewall-cmd" >&2
    fi
else
    echo "    WARNING: firewalld not found; ensure UDP ${MOSH_PORT_START}-${MOSH_PORT_END} is open manually" >&2
fi

# ------------------------------------------------------------------------------
# Verify
# ------------------------------------------------------------------------------
echo ""
echo "==> Verifying mosh-server..."
if command -v mosh-server >/dev/null 2>&1; then
    mosh-server --version 2>&1 | head -1
else
    echo "ERROR: mosh-server not found after install" >&2
    exit 1
fi

echo ""
echo "Mosh server setup complete."
echo "Client connection example:"
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
if [ -n "${PRIMARY_IP:-}" ]; then
    echo "  mosh ${USER}@${PRIMARY_IP} -- tmux new-session -A -s main"
else
    echo "  mosh ${USER}@<server-hostname> -- tmux new-session -A -s main"
fi
