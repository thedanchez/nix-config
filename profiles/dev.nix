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

    # Elixir / Erlang: the latest, Elixir 1.20 on OTP 29 (the projects pin
    # them with mise). OTP 29.1.2 from stable nixpkgs; Elixir pinned to 1.20.5
    # (security fixes: CVE-2026-109821, CVE-2026-115274, CVE-2026-97209) until
    # nixpkgs ships it (26.05 has 1.20.4) — then drop the override.
    beam.packages.erlang_29.erlang
    (beam.packages.erlang_29.elixir_1_20.overrideAttrs {
      version = "1.20.5";
      src = fetchFromGitHub {
        owner = "elixir-lang";
        repo = "elixir";
        rev = "v1.20.5";
        hash = "sha256-MsRNaWAQ05ysL3hOqpfhm//tRNL0Z4Ia/NfEWEQfEWE=";
      };
    })

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
