# ~/.bashrc.d/02-runtimes.sh
# Isolated developer paths and environmental initializations.
# Every external initializer is wrapped in an explicit existence check.

# Go toolchains (user-local and system-wide)
[ -d "$HOME/go/bin" ]         && export PATH="$HOME/go/bin:$PATH"
[ -d "/usr/local/go/bin" ]    && export PATH="/usr/local/go/bin:$PATH"

# Node Version Manager (NVM)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ]         && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# PNPM
[ -d "$HOME/.local/share/pnpm" ] && export PATH="$HOME/.local/share/pnpm:$PATH"

# FZF (Fedora system package)
[ -f /usr/share/fzf/shell/key-bindings.bash ] && . /usr/share/fzf/shell/key-bindings.bash
[ -f /usr/share/bash-completion/completions/fzf ] && . /usr/share/bash-completion/completions/fzf

# Atuin shell history integration (if installed)
if command -v atuin &>/dev/null; then
    eval "$(atuin init bash)"
fi

# Starship prompt (if installed)
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi
