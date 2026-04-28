{ pkgs, ... }:
let
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNL9cXko1AbnxnWiOjSHjkyH50cZYt5AHE4ofFM/ME3 DANCHEZ-RMB24"
  ];
in
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

  programs.zsh.enable = true;

  users.users.dan = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = authorizedKeys;
  };

  # Cortex service user — runs the BEAM VM, owns workspaces and data
  users.users.cortex = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [ "docker" "users" ];
    openssh.authorizedKeys.keys = authorizedKeys;
  };

  security.sudo.wheelNeedsPassword = false;
}
