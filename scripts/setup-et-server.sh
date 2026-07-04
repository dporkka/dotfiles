#!/usr/bin/env bash
# setup-et-server.sh — Idempotent EternalTerminal server setup for Fedora/RHEL.
#
# Run on the remote server (copy there first, e.g. with scp):
#   scp ~/dotfiles/scripts/setup-et-server.sh remotehost:/tmp/
#   ssh remotehost 'bash /tmp/setup-et-server.sh'
#
# This script installs the `et` package, opens TCP port 2022 in firewalld,
# and enables/starts the etserver systemd service.

set -euo pipefail

ET_PORT=2022

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
# Install EternalTerminal
# ------------------------------------------------------------------------------
echo "==> Installing EternalTerminal (et)..."
if ! rpm -q et >/dev/null 2>&1; then
    $SUDO dnf install -y et
else
    echo "    et is already installed"
fi

# ------------------------------------------------------------------------------
# Open firewall port
# ------------------------------------------------------------------------------
echo "==> Configuring firewall (port ${ET_PORT}/tcp)..."
if command -v firewall-cmd >/dev/null 2>&1; then
    if systemctl is-active --quiet firewalld; then
        $SUDO firewall-cmd --permanent --add-port="${ET_PORT}/tcp"
        $SUDO firewall-cmd --reload
        echo "    opened ${ET_PORT}/tcp in firewalld"
    else
        echo "    WARNING: firewalld is installed but not running; skipping firewall-cmd" >&2
    fi
else
    echo "    WARNING: firewalld not found; ensure port ${ET_PORT}/tcp is open manually" >&2
fi

# ------------------------------------------------------------------------------
# Enable and start etserver
# ------------------------------------------------------------------------------
echo "==> Enabling and starting etserver..."
$SUDO systemctl enable --now et

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo "==> Status:"
$SUDO systemctl status et --no-pager || true

echo ""
echo "ET server setup complete."
echo "Client connection example:"
# Try to show the primary non-loopback IP for convenience.
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
if [ -n "${PRIMARY_IP:-}" ]; then
    echo "  et ${USER}@${PRIMARY_IP}"
else
    echo "  et ${USER}@<server-hostname>"
fi
