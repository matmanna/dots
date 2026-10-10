# HTTPS on the tailnet for plain-HTTP services: `tailscale serve` publishes
# each one at https://<host>.<tailnet>.ts.net:<httpsPort> with a Tailscale
# certificate. Browsers that refuse plain http (Android Chrome's HTTPS-first
# mode) then work, and nothing is exposed beyond the tailnet.
{
  config,
  lib,
  ...
}:
let
  cfg = config.selfhost.tailnetServe;
in
{
  options.selfhost.tailnetServe = lib.mkOption {
    default = { };
    description = "Services to publish over HTTPS on the tailnet.";
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          options = {
            port = lib.mkOption {
              type = lib.types.port;
              description = "Local plain-HTTP port of the service.";
            };
            httpsPort = lib.mkOption {
              type = lib.types.port;
              default = config.port + 10000;
              description = "Tailnet HTTPS port (default: port + 10000).";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (cfg != { }) {
    systemd.services.tailnet-serve = {
      description = "Publish services over HTTPS on the tailnet";
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      path = [ config.services.tailscale.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "30s";
      };
      script = lib.concatStrings (
        lib.mapAttrsToList (_: s: ''
          tailscale serve --bg --https=${toString s.httpsPort} http://127.0.0.1:${toString s.port}
        '') cfg
      );
    };
  };
}
