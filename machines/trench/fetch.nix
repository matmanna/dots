# fastfetch greeting on SSH login: NixOS logo and accents in Catppuccin Mocha.
{ pkgs, ... }:
let
  # Catppuccin Mocha as 24-bit SGR codes.
  blue = "38;2;137;180;250";
  sapphire = "38;2;116;199;236";
  mauve = "38;2;203;166;247";
  pink = "38;2;245;194;231";
  surface2 = "38;2;88;91;112";

  config = (pkgs.formats.json { }).generate "fastfetch.jsonc" {
    logo = {
      source = "nixos";
      color = {
        "1" = blue;
        "2" = sapphire;
      };
      padding.right = 2;
    };
    display = {
      separator = "  ";
      color = {
        keys = mauve;
        title = blue;
      };
    };
    modules = [
      {
        type = "custom";
        format = "{#1;${pink}}welcome back to trench";
      }
      "break"
      "title"
      {
        type = "custom";
        format = "{#${surface2}}────────────────────────";
      }
      "os"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "cpu"
      "memory"
      "disk"
      "localip"
      "break"
      {
        type = "colors";
        symbol = "circle";
      }
    ];
  };
in
{
  environment.systemPackages = [ pkgs.fastfetch ];
  # Read from $XDG_CONFIG_DIRS, so it applies to every user.
  environment.etc."xdg/fastfetch/config.jsonc".source = config;

  # Interactive shells only: SSH logins and new herdr panes. Scripted
  # `ssh trench cmd` (deploy-rs included) is non-interactive and stays quiet.
  programs.zsh.interactiveShellInit = ''
    if [[ -n "$HERDR_PANE_ID" ]] || { [[ -n "$SSH_TTY" ]] && [[ -o login ]]; }; then
      fastfetch
    fi
  '';
  programs.bash.interactiveShellInit = ''
    if [[ -n "$HERDR_PANE_ID" ]] || { [[ -n "$SSH_TTY" ]] && shopt -q login_shell; }; then
      fastfetch
    fi
  '';
}
