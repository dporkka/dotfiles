# ~/.bash_profile - Login shell environment
# Host & Remote Server Target
#
# Absolute first guard: non-interactive login shells must exit immediately so
# GDM/GNOME session workers, cron, and forced-command SSH sessions are not
# stalled or broken by path/alias side effects.
[[ $- != *i* ]] && return

# ------------------------------------------------------------------------------
# Early environment
# ------------------------------------------------------------------------------
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less -R"

# Prepend user-local bin directories safely.
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/bin" ]       && export PATH="$HOME/bin:$PATH"

# ------------------------------------------------------------------------------
# Runtime initializers with strict, type-safe existence checks.
# Never source or execute a path that has not been verified to exist.
# ------------------------------------------------------------------------------
[ -f "$HOME/.cargo/env" ]                           && . "$HOME/.cargo/env"
[ -f "$HOME/.atuin/bin/atuin" ]                     && export PATH="$HOME/.atuin/bin:$PATH"
[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]    && . "$HOME/.nix-profile/etc/profile.d/nix.sh"

# ------------------------------------------------------------------------------
# Load interactive configuration for login+interactive shells.
# .bashrc contains its own non-interactive guard, so sourcing it here is safe.
# ------------------------------------------------------------------------------
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
