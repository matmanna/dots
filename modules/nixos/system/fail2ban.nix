# Adapted from taciturnaxolotl/dots (modules/nixos/system/fail2ban.nix).
{
  lib,
  config,
  ...
}:
let
  cfg = config.selfhost.fail2ban;
in
{
  options.selfhost.fail2ban = {
    enable = lib.mkEnableOption ''
      fail2ban with an sshd jail. Not a substitute for key-only auth, but it
      cuts the scanner traffic that otherwise fills the journal
    '';

    ignoreIP = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "127.0.0.0/8"
        "::1"
        # Tailscale CGNAT: never ban over the tailnet, it is the way back in.
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
        # k3s pod and service networks.
        "10.42.0.0/16"
        "10.43.0.0/16"
      ];
      description = "CIDRs fail2ban will never ban.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      inherit (cfg) ignoreIP;

      # Repeat offenders earn progressively longer bans.
      bantime = "1h";
      bantime-increment = {
        enable = true;
        formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
        maxtime = "168h";
        overalljails = true;
      };

      jails.sshd.settings = {
        enabled = true;
        mode = "normal";
        port = "ssh";
        maxretry = 5;
        findtime = "10m";
      };
    };
  };
}
