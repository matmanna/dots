# Glance start page, reachable only over Tailscale: it listens on localhost
# and `tailscale serve` publishes it at https://<host>.<tailnet>.ts.net with a
# Tailscale-issued certificate, so the tailnet login is the authentication.
# Every selfhost.expose entry with a title shows up automatically (uptime
# monitor + link), next to extra links such as Orchard-hosted apps, so the list
# can't drift from what is actually deployed.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.selfhost.dashboard;

  exposed = lib.filter (s: s.title != null) (lib.attrValues config.selfhost.expose);
  sites =
    map (s: {
      inherit (s) title icon;
      url = "https://${s.domain}";
    }) exposed
    ++ cfg.extraSites;
in
{
  options.selfhost.dashboard = {
    enable = lib.mkEnableOption "the Glance dashboard";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = "Port Glance listens on, on localhost only.";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Port `tailscale serve` publishes the dashboard on, on the tailnet.";
    };

    extraSites = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.str);
      default = [ ];
      description = "More monitored links: { title; url; icon; }.";
    };

    links = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.str);
      default = [ ];
      description = "Plain links in the sidebar: { title; url; }.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.glance = {
      enable = true;
      settings = {
        server = {
          host = "127.0.0.1";
          inherit (cfg) port;
        };
        theme = {
          # Catppuccin Mocha.
          background-color = "240 21 15";
          contrast-multiplier = 1.2;
          primary-color = "217 92 83";
          positive-color = "115 54 76";
          negative-color = "347 70 65";
        };
        pages = [
          {
            name = config.networking.hostName;
            columns = [
              {
                size = "small";
                widgets = [
                  {
                    type = "server-stats";
                    servers = [
                      {
                        type = "local";
                        name = config.networking.hostName;
                      }
                    ];
                  }
                  {
                    type = "bookmarks";
                    groups = [ { links = cfg.links; } ];
                  }
                ];
              }
              {
                size = "full";
                widgets = [
                  {
                    type = "monitor";
                    title = "apps";
                    cache = "1m";
                    inherit sites;
                  }
                  {
                    type = "releases";
                    title = "upstream releases";
                    cache = "6h";
                    repositories = [
                      "nextcloud/server"
                      "dani-garcia/vaultwarden"
                      "Freika/dawarich"
                      "glanceapp/glance"
                    ];
                  }
                ];
              }
            ];
          }
        ];
      };
    };

    # Re-applied on every boot and deploy; serve config is idempotent.
    systemd.services.glance-tailscale-serve = {
      description = "Publish Glance on the tailnet with tailscale serve";
      wantedBy = [ "multi-user.target" ];
      after = [
        "tailscaled.service"
        "glance.service"
      ];
      wants = [ "tailscaled.service" ];
      path = [ config.services.tailscale.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "30s";
      };
      script = ''
        tailscale serve --bg --https=${toString cfg.httpsPort} http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
