{ ... }:
{
  age.secrets = {
    telegram-bot-token = {
      file = ../../secrets/telegram-bot-token.age;
      owner = "cortex";
      mode = "0400";
    };
    agent-github-token = {
      file = ../../secrets/agent-github-token.age;
      owner = "cortex";
      mode = "0400";
    };
    anthropic-api-key = {
      file = ../../secrets/anthropic-api-key.age;
      owner = "cortex";
      mode = "0400";
    };
    phx-secret-key-base = {
      file = ../../secrets/phx-secret-key-base.age;
      owner = "cortex";
      mode = "0400";
    };
  };
}
