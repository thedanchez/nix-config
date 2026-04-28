{ ... }:
{
  imports = [
    ../../../modules/common
    ../../../profiles/dev.nix
    ../common.nix
    ./disk-config.nix
    ./networking.nix
  ];

  networking.hostName = "fsn-dev-1";
  system.stateVersion = "25.11";
}
