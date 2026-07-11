#!/bin/bash
# prompt-inject.sh — Select an agent prompt via fzf and inject it into the active pane.
#
# Usage:
#   prompt-inject.sh                         # default: prefix="/ask "
#   prompt-inject.sh --prefix ''             # raw text, no prefix
#   prompt-inject.sh --prefix '!gpt '        # custom prefix
#   prompt-inject.sh --print                 # print selection to stdout
#
# Injects into:
#   - tmux active pane  (TMUX env var detected)
#   - wezterm pane      (WEZTERM_ORIGIN_PANE env var, or WEZTERM_PANE)
#   - stdout            (fallback / --print flag)

set -euo pipefail

PROMPTS_DIR="${HOME}/.config/prompts"
PREFIX="/ask "

# Parse flags
PRINT_ONLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="$2"
      shift 2
      ;;
    --print)
      PRINT_ONLY=true
      shift
      ;;
    *)
      echo "Usage: $0 [--prefix <prefix>] [--print]" >&2
      exit 1
      ;;
  esac
done

# List all .md prompts, strip extension
prompts=("$PROMPTS_DIR"/*.md)
if [[ ${#prompts[@]} -eq 0 ]]; then
  echo "No prompt files found in $PROMPTS_DIR" >&2
  exit 1
fi

# Build a list of names for fzf
names=()
for f in "${prompts[@]}"; do
  base=$(basename "$f" .md)
  names+=("$base")
done

# Show fzf picker
selection=$(printf "%s\n" "${names[@]}" | fzf --prompt='prompt> ' --height=12 --reverse)
if [[ -z "$selection" ]]; then
  exit 0
fi

prompt_file="$PROMPTS_DIR/$selection.md"
prompt_text=$(cat "$prompt_file")

# --print: just emit to stdout (for programmatic use or piping)
if $PRINT_ONLY; then
  echo "${PREFIX}${prompt_text}"
  exit 0
fi

# Inject into active pane
inject() {
  local text="$1"
  if [[ -n "${TMUX:-}" ]]; then
    # Under tmux: send to the active pane
    tmux send-keys -t "$(tmux display-message -p '#{pane_id}')" "${text}"
  elif [[ -n "${WEZTERM_ORIGIN_PANE:-}" ]]; then
    # Spawned from a wezterm keybinding; send to the captured origin pane
    printf '%s' "${text}" | wezterm cli send-text --pane-id "$WEZTERM_ORIGIN_PANE" --no-paste
  elif [[ -n "${WEZTERM_PANE:-}" ]]; then
    # Running inside wezterm; send to the current pane
    printf '%s' "${text}" | wezterm cli send-text --no-paste
  else
    # Fallback: print to stdout
    echo "${text}"
  fi
}

inject "${PREFIX}${prompt_text}"
