{ ... }:
{
  imports = [
    ./users.nix
    ./base.nix
    # The Cortex stack module (options only until a host sets
    # services.cortex.enable — fsn-dev-1 doesn't run the stack yet).
    ../cortex
  ];
}
