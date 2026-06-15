{ lib, pkgs, config, ... }:
# The Cortex fleet module (ADR 0022 D3/D4 + ADR 0024 step 4).
#
# Nix provisions the box, edge, secrets, and timers; Cortex itself runs as the
# SAME `docker compose --profile app` artifact dogfooded locally (ADR 0022
# Q3a) from a checkout of the cortex repo at `stackDir`. `ingress.mode` is the
# declared intent; this module realizes it at the OS tier (ADR 0022 Q3b):
#
#   tunnel → host cloudflared (token mode), ZERO inbound ports
#   proxy  → host Caddy with auto-TLS, inbound 80/443 (the only published ports)
#   edge   → the customer's own LB; reaching the app is their override (runbook)
#   local  → loopback only, nothing in front
#
# Firewall ports are DERIVED from the mode so OS and app cannot drift
# (ADR 0022 D4 Layer 3).
#
# Secrets ride agenix encrypted to the host key (ADR 0009 rail). The two
# UNRECOVERABLE secrets are delivered to the containers as MOUNTED FILES, off
# the environment (ADR 0022 D6.3) — so `docker inspect` / `/proc/<pid>/environ`
# can't read the master key; only the file mount holds it:
#   secrets/cortex-master-key.age      — RAW master-key value → mounted at
#                                        /run/secrets/cortex_master_key,
#                                        CORTEX_MASTER_KEY_FILE points there.
#   secrets/cortex-backup-password.age — RAW restic password value → mounted,
#                                        CORTEX_BACKUP_PASSWORD_FILE points there.
#   secrets/cortex-env.age             — the rest of the bootstrap env (DB host/
#                                        name/user, OPERATORS, SECRET_KEY_BASE, DB
#                                        passwords, BACKUP_REPOSITORY/S3_*…), still
#                                        sourced via EnvironmentFile. DB passwords +
#                                        SECRET_KEY_BASE move to files next, once
#                                        each has a *_FILE reader.
#   secrets/cortex-tunnel-token.age    — TUNNEL_TOKEN=… (tunnel mode only)
#
# The RAW-value files (cortex-master-key, cortex-backup-password) hold ONLY the
# secret value (no KEY= prefix), since they are mounted as files, not sourced.
# Create them with `agenix -e secrets/cortex-master-key.age` etc. after
# registering the host key in secrets.nix; the declarations below are gated on
# `enable`, so the flake stays buildable for hosts that don't run the stack.
let
  cfg = config.services.cortex;

  # ADR 0022 D6.3 — the two UNRECOVERABLE secrets (master key + restic password)
  # are delivered to the containers as MOUNTED FILES, never the environment, via
  # a generated compose override layered on top of the base files. The base still
  # passes `CORTEX_MASTER_KEY=${...:-}` (empty now that it's out of cortex-env),
  # and `Cortex.Env` prefers the `*_FILE` form; `backup.sh` reads
  # `CORTEX_BACKUP_PASSWORD_FILE`. The DB passwords + SECRET_KEY_BASE follow this
  # identical pattern once each has a `*_FILE` reader (a later slice) — they stay
  # in cortex-env for now.
  secretsOverride = pkgs.writeText "cortex-secrets.yml" (builtins.toJSON {
    secrets = {
      cortex_master_key.file = config.age.secrets.cortex-master-key.path;
      cortex_backup_password.file = config.age.secrets.cortex-backup-password.path;
    };
    services = {
      migrate = {
        secrets = [ "cortex_master_key" ];
        environment.CORTEX_MASTER_KEY_FILE = "/run/secrets/cortex_master_key";
      };
      app = {
        secrets = [ "cortex_master_key" ];
        environment.CORTEX_MASTER_KEY_FILE = "/run/secrets/cortex_master_key";
      };
      backup = {
        secrets = [ "cortex_backup_password" ];
        environment.CORTEX_BACKUP_PASSWORD_FILE = "/run/secrets/cortex_backup_password";
      };
    };
  });

  # The base compose file publishes NO app ports (ADR 0022 D4 Layer 2). Host
  # edges (Caddy/cloudflared) and local mode reach the app through the
  # loopback-only override the cortex repo ships for exactly this; `edge`
  # mode's publication belongs to the operator's own override. The secrets
  # override goes last so its file-mounts + `*_FILE` env land on top.
  composeFiles =
    [ "docker-compose.yml" ]
    ++ lib.optional (cfg.ingressMode != "edge") "docker-compose.local.yml"
    ++ [ secretsOverride ];

  compose =
    "${pkgs.docker-compose}/bin/docker-compose "
    + lib.concatMapStringsSep " " (f: "-f ${f}") composeFiles;

  domain = lib.removePrefix "https://" (lib.removeSuffix "/" cfg.externalUrl);
in
{
  options.services.cortex = {
    enable = lib.mkEnableOption "the Cortex stack (compose --profile app on this box)";

    stackDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/cortex/cortex";
      description = ''
        Checkout of the cortex repo — the compose file is the deployable
        artifact; `make app-upgrade` inside it is the upgrade path (pins
        cortex:<git-sha>, pre-upgrade backup; ADR 0024 D6).
      '';
    };

    ingressMode = lib.mkOption {
      type = lib.types.enum [ "tunnel" "proxy" "edge" "local" ];
      default = "tunnel";
      description = "How this instance is exposed (ADR 0022 D2). Tunnel is the recommended default: zero inbound ports.";
    };

    externalUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "https://cortex.example.com";
      description = "Public origin of the instance. Required for every mode except local (the app refuses to boot without it).";
    };

    backup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Nightly backup timer (ADR 0024 step 4). Runs the SAME shared
          dump→restic→stamp script as the compose floor — `compose --profile
          backup run --rm backup once` — so there is no third realization to
          drift. Needs CORTEX_BACKUP_REPOSITORY/PASSWORD in cortex-env; an
          unconfigured run fails loudly and the app's boot report shows the
          stale/missing stamp.
        '';
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "03:00";
        description = "systemd OnCalendar for the nightly run.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.ingressMode == "local" || cfg.externalUrl != "";
        message = "services.cortex: every ingress mode except local requires externalUrl (ADR 0022 D1 — no secure cookies/links without it).";
      }
      {
        assertion = cfg.ingressMode != "proxy" || lib.hasPrefix "https://" cfg.externalUrl;
        message = "services.cortex: proxy mode terminates TLS at Caddy — externalUrl must be https://.";
      }
    ];

    virtualisation.docker.enable = true;

    age.secrets =
      {
        cortex-env = {
          file = ../../secrets/cortex-env.age;
          owner = "cortex";
          mode = "0400";
        };
        # ADR 0022 D6.3 — the two unrecoverable secrets, decrypted to their own
        # tmpfs files (mounted into the containers, never sourced into the env).
        cortex-master-key = {
          file = ../../secrets/cortex-master-key.age;
          owner = "cortex";
          mode = "0400";
        };
        cortex-backup-password = {
          file = ../../secrets/cortex-backup-password.age;
          owner = "cortex";
          mode = "0400";
        };
      }
      // lib.optionalAttrs (cfg.ingressMode == "tunnel") {
        cortex-tunnel-token = {
          file = ../../secrets/cortex-tunnel-token.age;
          mode = "0400";
        };
      };

    # ADR 0022 D4 Layer 3: inbound ports derive from the declared intent.
    # tunnel dials out (zero inbound); proxy is the ONLY mode that publishes;
    # edge/local open nothing here (edge's LB is outside this box's config).
    networking.firewall.allowedTCPPorts =
      lib.mkIf (cfg.ingressMode == "proxy") [ 80 443 ];

    systemd.services.cortex-stack = {
      description = "Cortex stack (docker compose --profile app; ADR 0022 Q3a)";
      after = [ "docker.service" "network-online.target" ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        CORTEX_INGRESS_MODE = cfg.ingressMode;
      } // lib.optionalAttrs (cfg.externalUrl != "") {
        CORTEX_EXTERNAL_URL = cfg.externalUrl;
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "cortex";
        WorkingDirectory = cfg.stackDir;
        EnvironmentFile = config.age.secrets.cortex-env.path;
        ExecStart = "${compose} --profile app up -d --wait";
        ExecStop = "${compose} --profile app down";
        # First boot builds the release image from source (ADR 0024 D6 keeps
        # on-box builds until the first customer-provisioned deploy).
        TimeoutStartSec = "30min";
      };
    };

    # ADR 0024 step 4 — the fleet backup realization: a declarative nightly
    # timer around the shared script. Persistent=true means a box that was
    # down at 03:00 backs up on next boot instead of skipping a day.
    systemd.services.cortex-backup = lib.mkIf cfg.backup.enable {
      description = "Cortex nightly backup (dump → restic → stamp; ADR 0024)";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "cortex";
        WorkingDirectory = cfg.stackDir;
        EnvironmentFile = config.age.secrets.cortex-env.path;
        ExecStart = "${compose} --profile backup run --rm backup once";
      };
    };

    systemd.timers.cortex-backup = lib.mkIf cfg.backup.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        RandomizedDelaySec = "20min";
        Persistent = true;
      };
    };

    # ADR 0022 Q3b `proxy` — host Caddy terminates TLS (auto-renewed ACME) and
    # proxies to the loopback-published app port. Caddy overwrites
    # X-Forwarded-* on proxy by default, which IS the D1 header hygiene.
    services.caddy = lib.mkIf (cfg.ingressMode == "proxy") {
      enable = true;
      virtualHosts."${domain}".extraConfig = ''
        reverse_proxy 127.0.0.1:4000
      '';
    };

    # ADR 0022 Q3b `tunnel` — token-mode cloudflared dials OUT to Cloudflare's
    # edge (remote-managed: point the tunnel's public hostname at
    # http://localhost:4000 in the dashboard). Zero inbound ports.
    systemd.services.cortex-cloudflared = lib.mkIf (cfg.ingressMode == "tunnel") {
      description = "Cloudflare tunnel for the Cortex stack (ADR 0022 D2 tunnel mode)";
      after = [ "network-online.target" "cortex-stack.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        DynamicUser = true;
        EnvironmentFile = config.age.secrets.cortex-tunnel-token.path;
        ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
