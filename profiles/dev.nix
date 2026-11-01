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
    # Pinned past nixpkgs (26.05 ships 1.3.13, unstable 1.4.2): 1.4.4 carries
    # Bun's October security fixes, Brotli among them (CVE-2026-111497).
    (import ../pkgs/bun.nix {
      inherit pkgs;
      version = "1.4.4";
      hash = "sha256-SQxqWbkwuEx42tLBeD8BdpDH1bxUasS1yOkkDULCz3U=";
    })
    nodejs_24

    # Elixir / Erlang: Elixir 1.20 on OTP 29, what the projects pin (mise).
    # From stable nixpkgs, which carries both and gets security backports.
    beam.packages.erlang_29.erlang
    beam.packages.erlang_29.elixir_1_20

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
