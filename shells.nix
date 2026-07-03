{ pkgs }:

let
  common = with pkgs; [
    git
    just
    tmux
    tmuxp
    zellij
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
    direnv
    nix-direnv
    neovim
    uv
  ];

  goShell = with pkgs; [
    go
    gopls
    gotools
    go-tools
    delve
    gofumpt
    golangci-lint
  ];

  rustShell = with pkgs; [
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
    cargo-watch
  ];

  nodeShell = with pkgs; [
    nodejs
    corepack
    typescript
    prettierd
    biome
  ];

  pythonShell = with pkgs; [
    python3
    uv
    ruff
    pyright
    python3Packages.pytest
    python3Packages.debugpy
  ];

  mkShell =
    name: extra:
    pkgs.mkShell {
      inherit name;
      packages = common ++ extra;
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      LESS = "-R -F -i -J -M -W";
      shellHook = ''
        echo "${name} dev shell ready"
      '';
    };
in
{
  default = mkShell "default" [ ];
  go = mkShell "go" goShell;
  rust = mkShell "rust" rustShell;
  node = mkShell "node" nodeShell;
  python = mkShell "python" pythonShell;
  full = mkShell "full" (goShell ++ rustShell ++ nodeShell ++ pythonShell);
}
