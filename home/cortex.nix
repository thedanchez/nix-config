{ pkgs, ... }:
{
  home.username = "cortex";
  home.homeDirectory = "/home/cortex";
  home.stateVersion = "25.11";

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Cortex";
        email = "cortex@danchez.dev";
      };
    };
  };

  programs.bash.enable = true;
}
