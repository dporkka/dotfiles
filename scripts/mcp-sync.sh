#!/usr/bin/env bash
# =============================================================================
# mcp-sync.sh — register the unified MCP blueprint into Claude Code (idempotent).
#
# The blueprint at config/mcp/servers.json is the single source of truth. This
# script pushes every server in it into Claude Code at USER scope, so the core
# local servers are available in every Claude Code session, in any project.
# (avante.nvim consumes the SAME blueprint via mcphub.nvim — no duplication.)
#
# Usage: mcp-sync.sh [path/to/servers.json]
#   Re-run any time you edit the blueprint. Safe to run repeatedly.
# =============================================================================

set -euo pipefail

BLUEPRINT="${1:-$HOME/dotfiles/config/mcp/servers.json}"

command -v claude >/dev/null 2>&1 || { echo "Error: 'claude' CLI not found on PATH"; exit 1; }
command -v jq     >/dev/null 2>&1 || { echo "Error: 'jq' is required (sudo apt install jq)"; exit 1; }
[[ -f "$BLUEPRINT" ]] || { echo "Error: blueprint not found: $BLUEPRINT"; exit 1; }

echo "Syncing MCP servers from $BLUEPRINT into Claude Code (user scope)…"

jq -r '.mcpServers | keys[]' "$BLUEPRINT" | while read -r name; do
  cfg=$(jq -c ".mcpServers[\"$name\"]" "$BLUEPRINT")
  # remove-then-add = idempotent upsert (remove is a no-op if absent)
  claude mcp remove "$name" --scope user >/dev/null 2>&1 || true
  if claude mcp add-json "$name" "$cfg" --scope user >/dev/null 2>&1; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name (add-json failed — check: claude mcp add-json $name '$cfg' --scope user)"
  fi
done

echo ""
echo "Done. Verify with:  claude mcp list"
