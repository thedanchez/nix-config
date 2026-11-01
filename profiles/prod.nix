{ lib, ... }:
{
  # Prod role (ADR 0022 D4 Layer 3): the declarative hardening floor for a
  # fleet box. base.nix already carries most of D4 (SSH-key-only, no-password
  # root, fail2ban, deny-by-default firewall, Tailscale); this finishes it.
  # A prod host imports this AND enables services.cortex with its ingress
  # mode — firewall ports then derive from that intent, not from this file.

  # Root never logs in directly on a prod box — dan has sudo via wheel.
  services.openssh.settings.PermitRootLogin = lib.mkForce "no";

  # Journald and the store are capped for every box in base.nix; docker logs
  # are the rest of the observability budget here (ADR 0022) — cap them so
  # they can't eat the disk the database needs.
  virtualisation.docker.daemon.settings = {
    "log-driver" = "json-file";
    "log-opts" = {
      "max-size" = "50m";
      "max-file" = "5";
    };
  };

  # Unattended upgrades are deliberately NOT wired yet: system.autoUpgrade
  # against this private flake needs repo credentials on-box, and the ADR 0022
  # GitOps continuum names Comin (pull-based, auto-rollback) as the rung for
  # that — decide with the first real prod cutover, not before.
}
