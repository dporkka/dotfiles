# ~/.bashrc.d/04-prompt.sh — Agent context in prompt.
#
# When AGENT_TASK_ID is set (by agent-shell-hook.sh), show it in PS1 so
# every command line reminds you which task you're driving.

__agent_task_prompt() {
  if [[ -n "${AGENT_TASK_ID:-}" ]]; then
    # Pink/magenta task ID bracket.
    PS1="\[\033[38;5;211m\][${AGENT_TASK_ID}]\[\033[0m\] $PS1"
  fi
}

# Append to PROMPT_COMMAND (Fedora initializes it as an array).
PROMPT_COMMAND+=('__agent_task_prompt')
