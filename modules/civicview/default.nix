{ lib, pkgs, config, ... }:
# The Civic View stack: app + Postgres + the converter service (`docker-compose.prod.yml`) run from a
# checkout of thedanchez/civicview at `stackDir`, Caddy in front on the
# tailnet only, and a nightly pg_dump → restic → R2 backup.
#
# Secrets ride agenix, encrypted to the host key:
#   secrets/civicview-env.age               the app env, KEY=value (.env.prod:
#                                           SECRET_KEY_BASE, POSTGRES_PASSWORD,
#                                           PHX_HOST, ADMIN_PASSWORD, R2_*, …)
#   secrets/civicview-deploy-key.age        read-only GitHub deploy key (raw
#                                           OpenSSH private key)
#   secrets/civicview-restic-env.age        AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY
#                                           of the R2 backup-bucket token
#   secrets/civicview-restic-repository.age s3:https://<account>.r2.cloudflarestorage.com/civicview-backups/restic
#   secrets/civicview-restic-password.age   the restic repository password (raw)
#   secrets/civicview-caddy-env.age         CIVICVIEW_HOST=<MagicDNS name> — kept out
#                                           of this public repo; Caddy expands
#                                           {$CIVICVIEW_HOST} at startup
#   secrets/civicview-alert-smtp.age        (monitoring) a Resend API key that can
#                                           send — Alertmanager's SMTP password (raw)
#
# With `monitoring.enable`, the stack adds docker-compose.monitoring.yml:
# Prometheus, Alertmanager (alerts emailed through Resend) and Grafana, all on
# 127.0.0.1 (Grafana: ssh -L 3000:localhost:3000; GRAFANA_ADMIN_PASSWORD in
# the env file).
#
# Operating it (as dan, via sudo):
#   sudo systemctl start civicview-deploy     pull main, build, migrate, restart
#   sudo -u civicview civicview-compose …     any compose command, env loaded, e.g.
#     sudo -u civicview civicview-compose run --rm civicview bin/civic_view eval '…'
#   sudo systemctl start restic-backups-civicview   back up now
let
  cfg = config.services.civicview;
  envFile = config.age.secrets.civicview-env.path;
  dumpDir = "/var/backup/civicview";

  composeFiles = lib.concatMapStringsSep " " (f: "-f ${f}") (
    [ "docker-compose.prod.yml" ] ++ lib.optional cfg.monitoring.enable "docker-compose.monitoring.yml"
  );

  # docker compose with the app env loaded (compose interpolates
  # POSTGRES_PASSWORD from it) and a fixed project name, so container names
  # (civicview-db-1, …) don't depend on the checkout's directory.
  civicviewCompose = pkgs.writeShellApplication {
    name = "civicview-compose";
    runtimeInputs = [ pkgs.docker pkgs.docker-compose ];
    text = ''
      set -a
      # shellcheck disable=SC1091
      . ${envFile}
      ${lib.optionalString cfg.monitoring.enable "export ALERTMANAGER_SMTP_PASSWORD_FILE=${config.age.secrets.civicview-alert-smtp.path}"}
      set +a
      cd ${cfg.stackDir}
      exec docker-compose -p civicview ${composeFiles} "$@"
    '';
  };

  gitSsh = "${pkgs.openssh}/bin/ssh -i ${config.age.secrets.civicview-deploy-key.path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new";

  checkout = pkgs.writeShellApplication {
    name = "civicview-checkout";
    runtimeInputs = [ pkgs.git pkgs.coreutils ];
    text = ''
      export GIT_SSH_COMMAND="${gitSsh}"
      if [ ! -d ${cfg.stackDir}/.git ]; then
        git clone --branch ${cfg.branch} ${cfg.repo} ${cfg.stackDir}
      fi
      # compose reads `env_file: .env.prod` relative to the checkout.
      ln -sfn ${envFile} ${cfg.stackDir}/.env.prod
    '';
  };

  # With monitoring, before the app restarts: Prometheus restarts to load the
  # checkout's alert rules (docker/prometheus/alert_rules.yml; it has no
  # reload endpoint enabled), and CivicViewRestarted is silenced for its
  # 15-minute window, since a deploy restarts the app on purpose: the alert
  # speaks only for restarts nobody asked for.
  beforeAppRestart = lib.optionalString cfg.monitoring.enable ''
    civicview-compose restart prometheus
    starts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    ends=$(date -u -d "+20 minutes" +%Y-%m-%dT%H:%M:%SZ)
    curl -fsS -o /dev/null -H 'content-type: application/json' \
      -X POST http://127.0.0.1:9093/api/v2/silences \
      -d "{\"matchers\":[{\"name\":\"alertname\",\"value\":\"CivicViewRestarted\",\"isRegex\":false,\"isEqual\":true}],\"startsAt\":\"$starts\",\"endsAt\":\"$ends\",\"createdBy\":\"civicview-deploy\",\"comment\":\"deploy restarts the app\"}" \
      || echo "warning: could not silence CivicViewRestarted; expect its email"
  '';

  deploy = pkgs.writeShellApplication {
    name = "civicview-deploy";
    runtimeInputs = [ pkgs.git pkgs.curl pkgs.coreutils civicviewCompose ];
    text = ''
      export GIT_SSH_COMMAND="${gitSsh}"
      cd ${cfg.stackDir}
      git pull --ff-only origin ${cfg.branch}
      git log --oneline -1
      civicview-compose build civicview converter
      civicview-compose up -d --wait db
      civicview-compose run --rm civicview bin/migrate
      ${beforeAppRestart}
      civicview-compose up -d --wait
    '';
  };
in
{
  options.services.civicview = {
    enable = lib.mkEnableOption "the Civic View stack (app + Postgres via docker compose)";

    repo = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:thedanchez/civicview.git";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
    };

    stackDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/civicview/civicview";
      description = "Checkout of the civicview repo; docker-compose.prod.yml is the deployable artifact.";
    };

    monitoring.enable = lib.mkEnableOption "Prometheus, Alertmanager and Grafana (docker-compose.monitoring.yml)";

    backup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Nightly pg_dump → restic → R2.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "03:00";
        description = "systemd OnCalendar for the nightly backup (host time zone).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;

    users.groups.civicview = { };
    users.users.civicview = {
      isSystemUser = true;
      group = "civicview";
      extraGroups = [ "docker" ];
      home = "/var/lib/civicview";
      createHome = true;
    };

    age.secrets = {
      civicview-env = {
        file = ../../secrets/civicview-env.age;
        owner = "civicview";
        mode = "0400";
      };
      civicview-deploy-key = {
        file = ../../secrets/civicview-deploy-key.age;
        owner = "civicview";
        mode = "0400";
      };
      civicview-caddy-env.file = ../../secrets/civicview-caddy-env.age;
    } // lib.optionalAttrs cfg.monitoring.enable {
      # Bind-mounted into the Alertmanager container, which runs as nobody.
      civicview-alert-smtp = {
        file = ../../secrets/civicview-alert-smtp.age;
        owner = "nobody";
        mode = "0400";
      };
    } // lib.optionalAttrs cfg.backup.enable {
      civicview-restic-env.file = ../../secrets/civicview-restic-env.age;
      civicview-restic-repository.file = ../../secrets/civicview-restic-repository.age;
      civicview-restic-password.file = ../../secrets/civicview-restic-password.age;
    };

    environment.systemPackages = [ civicviewCompose ];

    systemd.services.civicview-checkout = {
      description = "Clone the Civic View repo (first boot only)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "civicview";
        ExecStart = lib.getExe checkout;
      };
    };

    # Boot: bring the stack up as it was last deployed. Deploys (pull, build,
    # migrate) are explicit: `systemctl start civicview-deploy`.
    systemd.services.civicview-stack = {
      description = "Civic View stack (docker compose, app + Postgres)";
      after = [ "docker.service" "civicview-checkout.service" ];
      requires = [ "docker.service" "civicview-checkout.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "civicview";
        ExecStart = "${lib.getExe civicviewCompose} up -d --wait";
        ExecStop = "${lib.getExe civicviewCompose} down";
        # The first start builds the release image from source.
        TimeoutStartSec = "30min";
      };
    };

    systemd.services.civicview-deploy = {
      description = "Deploy Civic View main (pull, build, migrate, restart)";
      after = [ "civicview-stack.service" ];
      requires = [ "docker.service" "civicview-checkout.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "civicview";
        ExecStart = lib.getExe deploy;
        TimeoutStartSec = "30min";
      };
    };

    # Tailnet-only ingress: Caddy gets the *.ts.net certificate from
    # tailscaled, and 443 is reachable only on tailscale0 (base.nix trusts it;
    # nothing opens 80/443 publicly). The app's port is published on
    # 127.0.0.1 only. The MagicDNS name comes from civicview-caddy-env.
    services.tailscale.permitCertUid = "caddy";
    systemd.services.caddy.serviceConfig.EnvironmentFile = config.age.secrets.civicview-caddy-env.path;
    services.caddy = {
      enable = true;
      # Caddy redacts Authorization itself; the API's X-Api-Key it would log.
      virtualHosts."{$CIVICVIEW_HOST}".logFormat = ''
        output file /var/log/caddy/access-civicview.log
        format filter {
          request>headers>X-Api-Key delete
        }
      '';
      virtualHosts."{$CIVICVIEW_HOST}".extraConfig = ''
        # A verification link's path carries its token (a credential)
        log_skip /verify-email/*

        reverse_proxy 127.0.0.1:4000 {
          # LiveView websockets + long-poll
          flush_interval -1
        }
      '';
    };

    services.restic.backups.civicview = lib.mkIf cfg.backup.enable {
      initialize = true;
      repositoryFile = config.age.secrets.civicview-restic-repository.path;
      passwordFile = config.age.secrets.civicview-restic-password.path;
      environmentFile = config.age.secrets.civicview-restic-env.path;
      paths = [ dumpDir ];
      backupPrepareCommand = ''
        ${pkgs.coreutils}/bin/install -d -m 0700 ${dumpDir}
        ${pkgs.docker}/bin/docker exec civicview-db-1 \
          pg_dump -U civicview -Fc civicview_prod > ${dumpDir}/civicview_prod.dump.tmp
        ${pkgs.coreutils}/bin/mv ${dumpDir}/civicview_prod.dump.tmp ${dumpDir}/civicview_prod.dump
      '';
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
        "--keep-yearly 3"
      ];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        RandomizedDelaySec = "20min";
        Persistent = true;
      };
    };
  };
}
