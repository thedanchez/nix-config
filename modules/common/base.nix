{ pkgs, ... }:
{
  time.timeZone = "America/New_York";

  # Allow pre-built Linux binaries to run (agent tools, etc.)
  programs.nix-ld.enable = true;

  # Mosh (resilient SSH)
  services.openssh.settings.X11Forwarding = false;
  programs.mosh.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    unstable.git
    htop
    curl
    wget
    tmux
    mosh
  ];

  # Tailscale VPN
  services.tailscale.enable = true;

  # Brute-force protection
  services.fail2ban.enable = true;

  # Baseline firewall: SSH only. Profiles open more ports as needed.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ 41641 ]; # Tailscale

    # Drop inbound IPv4 TCP carrying IP options (a header longer than 20
    # bytes): no legitimate TCP peer sends them, and they're how
    # CVE-2026-98432 (IPv4 TCP handshake use-after-free) is reached. Kept
    # after the fixed kernel as hardening. In `raw` PREROUTING, before
    # connection tracking, so it covers traffic routed to containers too.
    # Deleted first so a firewall reload doesn't stack copies.
    extraCommands = ''
      iptables -t raw -D PREROUTING -p tcp -m u32 --u32 "0>>24&0xF=6:15" \
        -m comment --comment "drop IPv4 TCP with IP options" -j DROP 2>/dev/null || true
      iptables -t raw -I PREROUTING -p tcp -m u32 --u32 "0>>24&0xF=6:15" \
        -m comment --comment "drop IPv4 TCP with IP options" -j DROP
    '';
    extraStopCommands = ''
      iptables -t raw -D PREROUTING -p tcp -m u32 --u32 "0>>24&0xF=6:15" \
        -m comment --comment "drop IPv4 TCP with IP options" -j DROP 2>/dev/null || true
    '';
  };

  # Multipath TCP: nothing here needs it, and an MPTCP listener (Go programs
  # such as Caddy open them by default) was the setup of CVE-2026-98432's
  # published exploit. Off for the host's namespace; new sockets fall back to TCP.
  boot.kernel.sysctl."net.mptcp.enabled" = 0;

  # The store and the journal can't grow unbounded on a small VPS: fsn-dev-1
  # filled its 38 GB disk (18 system generations, no GC) by November 2026.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;
  services.journald.extraConfig = ''
    SystemMaxUse=1G
  '';

  # Use flakes (already in your nix install but good to declare)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
