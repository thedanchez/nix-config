{ pkgs, config, ... }:
{
  systemd.services.cortex = {
    description = "Cortex Agent Platform";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HOME = "/home/cortex";
      MIX_ENV = "prod";
      PHX_SERVER = "true";
      PORT = "4000";
      DATABASE_PATH = "/home/cortex/data/cortex.db";
      LANG = "en_US.UTF-8";
    };

    path = [
      pkgs.unstable.elixir_1_19
      pkgs.gcc
      pkgs.gnumake
      pkgs.git
      pkgs.sqlite
    ];

    serviceConfig = {
      Type = "simple";
      User = "cortex";
      Group = "users";
      WorkingDirectory = "/home/cortex/app";
      ExecStart = "${pkgs.bash}/bin/bash -lc 'export SECRET_KEY_BASE=$(cat ${config.age.secrets.phx-secret-key-base.path}) && mix phx.server'";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStopSec = "30s";
    };
  };
}
