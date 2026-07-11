# ~/.bashrc.d/05-atuin.sh — Shared shell history across all panes/sessions.
#
# Install: curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
# Or via cargo: cargo install atuin

if command -v atuin &>/dev/null; then
  eval "$(atuin init bash --disable-up-arrow)"
  # --disable-up-arrow: keeps Ctrl-p / Up as standard bash history;
  # use Ctrl-r for atuin's fuzzy, ranked, synced search.
fi
