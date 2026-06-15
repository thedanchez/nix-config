let
  # User keys (can encrypt secrets from local machine)
  dan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNL9cXko1AbnxnWiOjSHjkyH50cZYt5AHE4ofFM/ME3";

  # Host keys (can decrypt secrets on the server)
  fsn-dev-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYeGGRYhr4LG2i1G/iQeHgzb9rgIb5U6NImZuwalrPT";

  allKeys = [ dan fsn-dev-1 ];
in
{
  # The Cortex stack (modules/cortex) — created when a host enables it:
  #   cortex-env.age             = the bootstrap env `cortex init` emits MINUS the
  #                                two secrets below (CORTEX_DB_*, CORTEX_OPERATORS,
  #                                CORTEX_SECRET_KEY_BASE, BACKUP_REPOSITORY/S3_*…).
  #   cortex-master-key.age      = the RAW master-key value (ADR 0009), delivered
  #                                as a MOUNTED FILE not the environment (ADR 0022
  #                                D6.3) → CORTEX_MASTER_KEY_FILE in the container.
  #   cortex-backup-password.age = the RAW restic password value, same rail →
  #                                CORTEX_BACKUP_PASSWORD_FILE.
  #   cortex-tunnel-token.age    = TUNNEL_TOKEN=… (tunnel ingress mode only)
  #
  # Backing up THIS REPO + the operator age key off-box covers both unrecoverable
  # secrets (master key + restic password; ADR 0024 D3).
  "secrets/cortex-env.age".publicKeys = allKeys;
  "secrets/cortex-master-key.age".publicKeys = allKeys;
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
