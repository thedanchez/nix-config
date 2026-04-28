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
  };

  # Use flakes (already in your nix install but good to declare)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
