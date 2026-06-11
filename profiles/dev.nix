{ pkgs, ... }:
{
  # Docker
  virtualisation.docker.enable = true;

  # No edge service and no inbound 80/443 here (ADR 0022 D4 Layer 3): ingress
  # is declared via services.cortex.ingressMode, which derives the firewall
  # and runs the right edge (Caddy/cloudflared) itself. A dev box without the
  # stack enabled exposes SSH + Tailscale only.

  environment.systemPackages = with pkgs; [
    # Go
    go
    # JavaScript / TypeScript
    (import ../pkgs/bun.nix {
      inherit pkgs;
      version = "1.3.13";
      hash = "sha256-r2XOCbddEr4az75VZ+WjTGLwD5LEE7t0LnD+l1VmhIw=";
    })
    nodejs_24

    # Elixir / Erlang (Elixir 1.19 + OTP 28)
    unstable.elixir_1_19

    # Python
    python3

    # Rust
    rustc
    cargo
    rustfmt
    clippy

    # C / C++
    gcc
    gnumake
    cmake

    # General dev tools
    jq
    ripgrep
    fd
    tree
    unzip
    file
    strace
    direnv

    # Modern CLI replacements
    bat       # better cat
    eza       # better ls
    fzf       # fuzzy finder
    zoxide    # better cd
    lazygit   # git TUI
    delta     # better git diffs
  ];
}
