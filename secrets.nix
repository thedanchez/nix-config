let
  # User keys (can encrypt secrets from local machine)
  dan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNL9cXko1AbnxnWiOjSHjkyH50cZYt5AHE4ofFM/ME3";

  # Host keys (can decrypt secrets on the server)
  fsn-dev-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYeGGRYhr4LG2i1G/iQeHgzb9rgIb5U6NImZuwalrPT";

  allKeys = [ dan fsn-dev-1 ];
in
{
  "secrets/telegram-bot-token.age".publicKeys = allKeys;
  "secrets/agent-github-token.age".publicKeys = allKeys;
  "secrets/anthropic-api-key.age".publicKeys = allKeys;
  "secrets/phx-secret-key-base.age".publicKeys = allKeys;
}
