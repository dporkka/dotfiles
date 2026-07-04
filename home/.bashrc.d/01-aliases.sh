# ~/.bashrc.d/01-aliases.sh
# Standard development aliases (interactive shells only).

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Listing
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Search
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Safer file operations
alias mkdir='mkdir -pv'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'

# System overview
alias df='df -h'
alias du='du -h'
alias free='free -h'

# Development
alias py='python3'
alias g='git'
alias gs='git status'
alias gp='git pull'
alias gl='git log --oneline --graph --decorate -20'
alias d='docker'
alias dc='docker compose'
alias k='kubectl'

# EternalTerminal + Tmux helpers
alias etmux='et -c "tmux new-session -A -s main"'

# Mosh + Tmux helper (UDP roaming; pass host as first argument)
moshmux() {
    local host="${1:?usage: moshmux <host>}"
    mosh "$host" -- tmux new-session -A -s main
}
