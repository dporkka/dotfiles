#!/usr/bin/env bash
# =============================================================================
# claude-destructive-guard.sh — Claude Code hook guard against destructive ops.
#
# Designed to be installed as a Claude Code hook (e.g.
# ~/.claude/hooks/pre-tool-use).  It reads the tool invocation from stdin or a
# file argument and blocks commands that match known system-destroying patterns.
#
# Exit codes:
#   0  allowed (or bypassed with CLAUDE_ALLOW_DANGEROUS=1)
#   1  blocked
#   2  usage / input error
# =============================================================================
set -euo pipefail

usage() {
  echo "Usage: $0 [tool-input.json]" >&2
  echo "Reads tool input from stdin when no file is given." >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 2
fi

if [[ $# -eq 1 ]]; then
  if [[ ! -r "$1" ]]; then
    echo "Error: cannot read $1" >&2
    exit 2
  fi
  INPUT="$(cat "$1")"
else
  if [[ -t 0 ]]; then
    usage
    exit 2
  fi
  INPUT="$(cat)"
fi

[[ -z "${INPUT:-}" ]] && exit 0

# Extended-regex patterns for destructive command signatures.
PATTERNS=(
  # Recursive removal of root or all direct children of root.
  'rm[[:space:]]+-rf[[:space:]]+/([^[:alnum:]._/]|$)'
  'rm[[:space:]]+-rf[[:space:]]+/\*'

  # Disk overwrite / partitioning / filesystem creation.
  'dd[[:space:]]+.*of=/dev/'
  'mkfs\.'
  'fdisk[[:space:]]+/dev/'
  'parted[[:space:]]+/dev/'
  '>[[:space:]]*/dev/sd'
  'shred[[:space:]]+/dev/'

  # Fork bomb variants.
  ':\(\)\{ :\|:& \};:'
  ':\(\)\{:\|:&\};:'
)

matched=""
for pat in "${PATTERNS[@]}"; do
  if grep -Eiq -- "$pat" <<< "$INPUT"; then
    matched="$pat"
    break
  fi
done

[[ -z "$matched" ]] && exit 0

if [[ "${CLAUDE_ALLOW_DANGEROUS:-}" == "1" ]]; then
  echo "WARNING: destructive pattern detected ($matched). Bypassed because CLAUDE_ALLOW_DANGEROUS=1." >&2
  exit 0
fi

echo "BLOCKED: destructive command pattern detected ($matched)." >&2
echo "If you are absolutely sure, rerun with CLAUDE_ALLOW_DANGEROUS=1." >&2
exit 1
