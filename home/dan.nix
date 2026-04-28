{ pkgs, ... }:
{
  home.username = "dan";
  home.homeDirectory = "/home/dan";
  home.stateVersion = "25.11";

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Daniel Sanchez";
        email = "dsanc89@icloud.com";
      };
      alias = {
      # Add/Stage
      a = "add";
      ap = "add -p";
      align = "!f() { GIT_BRANCH=$(git branch --show-current) && git checkout $2 && git fetch $1 && git rebase $1/$2 && git checkout $GIT_BRANCH && git rebase $2; };f";

      # Branch
      br = "branch";
      branches = "branch -a";

      # Checkout
      co = "checkout";
      cob = "checkout -b";

      # Commit
      c = "commit --verbose";
      ca = "commit --amend --verbose";
      cah = "commit --amend -C head";
      cm = "commit -m";
      cp = "cherry-pick";

      # Diff
      d = "diff";
      ds = "diff --staged";
      dc = "diff --cached";

      # Pull
      pr = "pull --rebase";

      # Push
      pf = "push --force-with-lease";

      # Reset
      r = "reset";
      rh = "reset --hard";

      # Status
      st = "status";

      # Unstage
      unstage = "reset HEAD";

      # WIP
      wip = "commit -m \"WIP\"";

      # Log
      llog = "log --date=local";
      flog = "log --pretty=fuller --decorate";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --abbrev=8 --date=relative";
      lol = "log --graph --decorate --oneline";
      lola = "log --graph --decorate --oneline --all";
      blog = "log origin/master... --left-right";

      # List
      lb = "!git for-each-ref --sort='-authordate' --format='%(authordate)%09%(objectname:short)%09%(refname)' refs/heads | sed -e 's-refs/heads/--'";
      la = "!git config -l | grep alias | cut -c 7-";
      };
    };
  };

  programs.bash.enable = true;

  # Zsh
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ls = "eza";
      ll = "eza -la";
      lt = "eza --tree";
      cat = "bat";
    };
  };

  # Direnv (auto-load per-project envs)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Zoxide (smart cd)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Fzf (fuzzy finder)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Delta (git diff pager)
  programs.git.settings.core.pager = "delta";
  programs.git.settings.interactive.diffFilter = "delta --color-only";
  programs.git.settings.delta = {
    navigate = true;
    light = false;
  };

}
