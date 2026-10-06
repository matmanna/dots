# zsh as the default shell, close to the oh-my-zsh setup on clancy.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.selfhost.zsh;
in
{
  options.selfhost.zsh.enable = lib.mkEnableOption "zsh with oh-my-zsh as every user's shell";

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      histSize = 50000;
      ohMyZsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = [
          "git"
          "sudo"
          "kubectl"
          "systemd"
        ];
      };
      shellAliases = {
        k = "kubectl";
        rebuild-log = "journalctl -b -u orchard-deploy -u k3s --no-pager -n 50";
      };
      setOptions = [
        "HIST_IGNORE_ALL_DUPS"
        "HIST_REDUCE_BLANKS"
        "SHARE_HISTORY"
        "EXTENDED_HISTORY"
      ];
    };

    users.defaultUserShell = pkgs.zsh;
    users.users.root.shell = pkgs.zsh;
  };
}
