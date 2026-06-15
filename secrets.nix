let
  # User keys (can encrypt secrets from local machine)
  dan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNL9cXko1AbnxnWiOjSHjkyH50cZYt5AHE4ofFM/ME3";

  # Host keys (can decrypt secrets on the server)
  fsn-dev-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYeGGRYhr4LG2i1G/iQeHgzb9rgIb5U6NImZuwalrPT";

  allKeys = [ dan fsn-dev-1 ];
in
{
  # The Cortex stack (modules/cortex) — created when a host enables it:
  # Each of these holds ONLY a RAW secret value (no KEY= prefix) and is delivered
  # to the containers as a MOUNTED FILE, off the environment (ADR 0022 D6.3):
  #   cortex-master-key.age      → CORTEX_MASTER_KEY_FILE
  #   cortex-secret-key-base.age → CORTEX_SECRET_KEY_BASE_FILE
  #   cortex-db-app-password.age → CORTEX_DB_APP_PASSWORD_FILE
  #   cortex-backup-password.age → CORTEX_BACKUP_PASSWORD_FILE
  #   cortex-env.age             = the rest of the bootstrap env, KEY=value form
  #                                (CORTEX_DB_HOST/NAME/USER, the OWNER
  #                                CORTEX_DB_PASSWORD — pg_dump needs it as
  #                                PGPASSWORD, no _FILE — CORTEX_OPERATORS,
  #                                BACKUP_REPOSITORY/S3_*…). EnvironmentFile-sourced.
  #   cortex-tunnel-token.age    = TUNNEL_TOKEN=… (tunnel ingress mode only)
  #
  # Backing up THIS REPO + the operator age key off-box covers both unrecoverable
  # secrets (master key + restic password; ADR 0024 D3).
  "secrets/cortex-env.age".publicKeys = allKeys;
  "secrets/cortex-master-key.age".publicKeys = allKeys;
  "secrets/cortex-secret-key-base.age".publicKeys = allKeys;
  "secrets/cortex-db-app-password.age".publicKeys = allKeys;
  "secrets/cortex-backup-password.age".publicKeys = allKeys;
  "secrets/cortex-tunnel-token.age".publicKeys = allKeys;

  # Retired (pre-Vault scaffold era): bot/provider tokens now live in the
  # in-app Vault (ADR 0009) and the API key rides cortex-env for `cortex
  # apply`. Kept listed so the existing files stay rekey-able; delete the
  # .age files once confirmed stale.
  "secrets/telegram-bot-token.age".publicKeys = allKeys;
  "secrets/agent-github-token.age".publicKeys = allKeys;
  "secrets/anthropic-api-key.age".publicKeys = allKeys;
  "secrets/phx-secret-key-base.age".publicKeys = allKeys;
}
