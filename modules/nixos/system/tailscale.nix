{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.selfhost.tailscale;
in
{
  options.selfhost.tailscale.enable = lib.mkEnableOption "Tailscale, trusted as an admin network";

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    # Every tailnet-only service rides on tailscaled: keep it responsive
    # when something else pegs the CPU.
    systemd.services.tailscaled.serviceConfig.CPUWeight = 500;

    # From taciturnaxolotl/dots (tailscale-deferred-restart.nix): once deploys
    # run over the tailnet, restarting tailscaled mid-activation cuts the
    # deploy's own SSH connection and deploy-rs rolls back a good deploy. So
    # leave tailscaled out of the switch and restart it two minutes later,
    # only when its package actually changed.
    systemd.services.tailscaled.restartIfChanged = false;

    systemd.services.tailscaled-deferred-restart = {
      description = "Restart tailscaled once the deploy has let go of the connection";
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscaled.service" ];
      restartTriggers = [ config.services.tailscale.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.systemd ];
      script = ''
        pid=$(systemctl show -p MainPID --value tailscaled.service)
        running=$(readlink "/proc/$pid/exe" 2>/dev/null || true)
        want=${config.services.tailscale.package}/bin/.tailscaled-wrapped

        # At boot the two already agree, so this is a no-op.
        [ "$running" = "$want" ] && exit 0

        systemd-run --on-active=120 --description="deferred tailscaled restart" \
          systemctl restart tailscaled.service
      '';
    };
  };
}
