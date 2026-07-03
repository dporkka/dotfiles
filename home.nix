{
  config,
  pkgs,
  username,
  homeDirectory,
  ...
}:
{
  home = {
    inherit username homeDirectory;
    stateVersion = "24.11";

    packages = with pkgs; [
      # Core workflow
      git
      just
      tmux
      tmuxp
      zellij

      # Shell essentials
      fzf
      zoxide
      starship
      eza
      bat
      ripgrep
      fd
      jq
      yq-go
      delta
      lazygit
      gh

      # Nix helpers
      direnv
      nix-direnv
      nixfmt-rfc-style

      # Languages / runtimes (global availability)
      uv
      nodejs
      go
      rustc
      cargo

      # Editors
      neovim

      # Utilities
      wget
      curl
      tree
      htop
      btop
      unzip
      zip
    ];

    # Session variables are intentionally omitted here so home-manager does
    # not need to overwrite ~/.profile. They are set in dev shells instead.
  };

  # Let home-manager install and manage itself.
  programs.home-manager.enable = true;

  # Install direnv/nix-direnv but do not hook into bash/zsh automatically,
  # because those configs are already managed by this repo. Add this to your
  # shell config manually if you want directory-local env loading:
  #   eval "$(direnv hook bash)"   # or zsh
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };
}
