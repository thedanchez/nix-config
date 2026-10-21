{ ... }:
{
  imports = [
    ../../../modules/common
    ../../../profiles/prod.nix
    ../common.nix
    ./disk-config.nix
  ];

  networking.hostName = "ash-prod-1";

  services.civicview.enable = true;

  system.stateVersion = "25.11";
}
