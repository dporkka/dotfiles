# ~/.bashrc - Unified interactive shell configuration
# Host & Remote Server Target
#
# Absolute first guard: non-interactive shells must exit immediately so GDM,
# GNOME background/session workers, cron jobs, SSH forced commands, scp, rsync,
# and similar non-interactive callers are never blocked or polluted by this file.
[[ $- != *i* ]] && return

# ------------------------------------------------------------------------------
# Global definitions (Fedora default) -- loaded only if present.
# ------------------------------------------------------------------------------
[ -f /etc/bashrc ] && . /etc/bashrc

# ------------------------------------------------------------------------------
# Core interactive settings
# ------------------------------------------------------------------------------
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export HISTSIZE=100000
export HISTFILESIZE=200000
export HISTCONTROL="erasedups:ignoreboth"
export HISTTIMEFORMAT="%F %T "

shopt -s histappend
shopt -s cmdhist
shopt -s checkwinsize

# ------------------------------------------------------------------------------
# Type-safe prompt hooks
# Fedora initializes PROMPT_COMMAND as an array. All per-prompt hooks must be
# appended with the +=('...') form to avoid dropping entries or core dumps.
# ------------------------------------------------------------------------------
__bashrc_prompt_hook() {
    # Lightweight per-prompt anchor. Add custom logic here if needed.
    :
}
PROMPT_COMMAND+=('__bashrc_prompt_hook')

# ------------------------------------------------------------------------------
# Modular sub-profile loading: ~/.bashrc.d/
# ------------------------------------------------------------------------------
if [[ -d "$HOME/.bashrc.d" ]]; then
    for __bashrc_fragment in "$HOME/.bashrc.d"/*.sh; do
        [[ -r "$__bashrc_fragment" ]] && . "$__bashrc_fragment"
    done
    unset __bashrc_fragment
fi
