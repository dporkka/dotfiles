#!/usr/bin/env bash
# =============================================================================
# newproj.sh — scaffold a new development project.
#
# Usage:
#   newproj.sh <project-name> [options]
#
# Options:
#   --path /some/dir        Parent directory for the project (default: ~/dev)
#   --stack node|go|python|rust  Primary language/stack for the AGENTS.md template
#   --tmuxp                 Create a tmuxp session file at ~/.config/tmuxp/<name>.yaml
#   --claude                Seed .claude/settings.local.json with project context
#   --force                 Overwrite an existing directory
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Defaults
# -----------------------------------------------------------------------------
PROJECT_NAME=""
PROJECT_PATH="${PROJECT_PATH:-$HOME/dev}"
STACK=""
WITH_TMUXP=false
WITH_CLAUDE=false
FORCE=false

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
log()  { echo "==> $*"; }
warn() { echo "⚠ $*" >&2; }
fail() { echo "✗ $*" >&2; exit 1; }

camel_case() {
  local str="$1"
  # Replace hyphens/underscores with spaces, title-case each word, then concat.
  str="${str//-/ }"
  str="${str//_/ }"
  local out=""
  for word in $str; do
    out+="${word^}"
  done
  printf '%s' "$out"
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path=*) PROJECT_PATH="${1#--path=}"; shift ;;
    --path)   PROJECT_PATH="${2:-$HOME/dev}"; shift 2 ;;
    --stack=*) STACK="${1#--stack=}"; shift ;;
    --stack)   STACK="${2:-}"; shift 2 ;;
    --tmuxp)   WITH_TMUXP=true; shift ;;
    --claude)  WITH_CLAUDE=true; shift ;;
    --force)   FORCE=true; shift ;;
    --help|-h)
      sed -n '/^# Usage:/,/^#   --force/p' "$0" | sed 's/^# //'
      exit 0
      ;;
    -*)
      fail "Unknown option: $1" ;;
    *)
      if [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME="$1"
      else
        fail "Only one project name is allowed (got: $PROJECT_NAME and $1)"
      fi
      shift
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
if [[ -z "$PROJECT_NAME" ]]; then
  fail "Project name is required. Usage: newproj.sh <project-name> [options]"
fi

if [[ "$PROJECT_NAME" =~ [^a-zA-Z0-9_-] ]]; then
  warn "Project name contains characters beyond letters, numbers, hyphens, and underscores."
fi

if [[ -n "$STACK" ]]; then
  case "$STACK" in
    node|go|python|rust) ;;
    *) fail "Unsupported stack '$STACK'. Use node, go, python, or rust." ;;
  esac
fi

# -----------------------------------------------------------------------------
# Directory setup
# -----------------------------------------------------------------------------
TARGET_DIR="$PROJECT_PATH/$PROJECT_NAME"

if [[ -e "$TARGET_DIR" ]]; then
  if [[ "$FORCE" == true ]]; then
    warn "Overwriting existing directory: $TARGET_DIR"
  else
    fail "Directory already exists: $TARGET_DIR (use --force to overwrite)"
  fi
fi

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# -----------------------------------------------------------------------------
# Git init
# -----------------------------------------------------------------------------
if [[ ! -d "$TARGET_DIR/.git" ]] || [[ "$FORCE" == true ]]; then
  git init --quiet
  log "Initialized git repository in $TARGET_DIR"
else
  log "Git repository already exists in $TARGET_DIR"
fi

# -----------------------------------------------------------------------------
# AGENTS.md template
# -----------------------------------------------------------------------------
DISPLAY_NAME=$(camel_case "$PROJECT_NAME")

AGENTS_MD="$TARGET_DIR/AGENTS.md"

if [[ ! -f "$AGENTS_MD" ]] || [[ "$FORCE" == true ]]; then
  cat > "$AGENTS_MD" <<EOF
# $DISPLAY_NAME

## Project

- **Name:** $PROJECT_NAME
- **Path:** $TARGET_DIR
- **Stack:** ${STACK:-<not specified>}
- **Created:** $(date -Iseconds)

## Conventions

- Keep code modular and well-tested.
- Match the existing style of the codebase.
- Prefer explicit, readable code over clever one-liners.
- Document public APIs and non-obvious behavior.

## Key Files

- \`README.md\` — project overview and getting-started instructions.
- \`AGENTS.md\` — this file; update it as the project evolves.

## Build / Run / Test

<!-- Add the canonical commands for this stack below. -->

\`\`\`bash
# TODO: add build/test/run commands
\`\`\`

## Notes

<!-- Capture important context, gotchas, and decisions here. -->
EOF
  log "Created $AGENTS_MD"
fi

# -----------------------------------------------------------------------------
# Optional tmuxp session file
# -----------------------------------------------------------------------------
if [[ "$WITH_TMUXP" == true ]]; then
  TmuxP_DIR="$HOME/.config/tmuxp"
  TmuxP_FILE="$TmuxP_DIR/${PROJECT_NAME}.yaml"
  mkdir -p "$TmuxP_DIR"

  cat > "$TmuxP_FILE" <<EOF
session_name: $PROJECT_NAME
start_directory: $TARGET_DIR
windows:
  - window_name: editor
    panes:
      - nvim
  - window_name: shell
    panes:
      -
EOF
  log "Created tmuxp session file: $TmuxP_FILE"
fi

# -----------------------------------------------------------------------------
# Optional Claude Code settings
# -----------------------------------------------------------------------------
if [[ "$WITH_CLAUDE" == true ]]; then
  CLAUDE_DIR="$TARGET_DIR/.claude"
  CLAUDE_SETTINGS="$CLAUDE_DIR/settings.local.json"
  mkdir -p "$CLAUDE_DIR"

  cat > "$CLAUDE_SETTINGS" <<EOF
{
  "project": {
    "name": "$PROJECT_NAME",
    "displayName": "$DISPLAY_NAME",
    "stack": "${STACK:-unknown}",
    "root": "$TARGET_DIR"
  },
  "notes": [
    "See AGENTS.md for project conventions and key files."
  ]
}
EOF
  log "Created $CLAUDE_SETTINGS"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "Project '$PROJECT_NAME' ready at: $TARGET_DIR"
[[ -n "$STACK" ]] && echo "Stack: $STACK"
[[ "$WITH_TMUXP" == true ]] && echo "Tmuxp:  $HOME/.config/tmuxp/${PROJECT_NAME}.yaml"
[[ "$WITH_CLAUDE" == true ]] && echo "Claude: $TARGET_DIR/.claude/settings.local.json"
echo ""
echo "Next steps:"
echo "  cd $TARGET_DIR"
echo "  ${EDITOR:-nvim} ."
