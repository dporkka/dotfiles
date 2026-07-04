#!/usr/bin/env bash
# =============================================================================
# backup-home-gdrive.sh — daily whole-home backup to Google Drive via rclone
# =============================================================================
#
# Usage:
#   backup-home-gdrive.sh           # run a real backup
#   backup-home-gdrive.sh --dry-run # preview changes without uploading
#
# Environment:
#   RCLONE_REMOTE  — rclone remote name (default: gdrive)
#   DOTS           — path to dotfiles repo (default: ~/dotfiles)
#
# The script syncs $HOME to gdrive:Backups/<hostname>-home and moves
# overwritten/deleted files to a timestamped backup-dir on Google Drive.
# =============================================================================

set -euo pipefail

REMOTE_NAME="${RCLONE_REMOTE:-gdrive}"
DOTS="${DOTS:-$HOME/dotfiles}"
SOURCE="$HOME"
FILTER_FILE="$DOTS/config/rclone/backup-filters.txt"
HOSTNAME="$(hostname)"
REMOTE_ROOT="${REMOTE_NAME}:Backups/${HOSTNAME}-home"
VERSION_DIR="${REMOTE_NAME}:Backups/${HOSTNAME}-home-versions/$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$HOME/.local/state/rclone"
LOG_FILE="$LOG_DIR/backup.log"
DRY_RUN=""

usage() {
  cat <<'EOF'
Usage: backup-home-gdrive.sh [OPTIONS]

Options:
  -n, --dry-run   Show what would be uploaded/deleted without making changes.
  -h, --help      Show this help message.

Environment:
  RCLONE_REMOTE   rclone remote name (default: gdrive)
  DOTS            path to dotfiles repo (default: ~/dotfiles)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN="--dry-run"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------

if ! command -v rclone >/dev/null 2>&1; then
  echo "ERROR: rclone not found on PATH" >&2
  exit 1
fi

if ! rclone config show "$REMOTE_NAME" >/dev/null 2>&1; then
  echo "ERROR: rclone remote '$REMOTE_NAME' not found" >&2
  echo "Run: rclone config" >&2
  exit 1
fi

if [[ ! -f "$FILTER_FILE" ]]; then
  echo "ERROR: filter file not found: $FILTER_FILE" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

# -----------------------------------------------------------------------------
# Run backup
# -----------------------------------------------------------------------------

echo "Source:      $SOURCE"
echo "Remote:      $REMOTE_ROOT"
echo "Backup dir:  $VERSION_DIR"
echo "Filter file: $FILTER_FILE"
echo "Log file:    $LOG_FILE"
if [[ -n "$DRY_RUN" ]]; then
  echo "Mode:        DRY RUN"
fi

# shellcheck disable=SC2086
rclone sync "$SOURCE" "$REMOTE_ROOT" \
  --filter-from "$FILTER_FILE" \
  --backup-dir "$VERSION_DIR" \
  --transfers 4 \
  --checkers 8 \
  --fast-list \
  --max-size 100M \
  --progress \
  --stats-one-line-date \
  --log-file "$LOG_FILE" \
  --log-level INFO \
  $DRY_RUN

echo "Backup complete."
