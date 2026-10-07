# Glance start page behind a login. Every selfhost.expose entry with a title
# shows up automatically (uptime monitor + link), next to extra links such as
# Orchard-hosted apps, so the list can't drift from what is actually deployed.
{
  config,
  lib,
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

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Public hostname of the dashboard.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8083;
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "Login name.";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "File with the session signing key (glance secret:make).";
    };

    passwordHashFile = lib.mkOption {
      type = lib.types.path;
      description = "File with the bcrypt hash of the password (glance password:hash).";
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
          host = "0.0.0.0";
          inherit (cfg) port;
          # Behind Traefik: trust X-Forwarded-For for the login rate limit.
          proxied = true;
        };
        auth = {
          secret-key._secret = cfg.secretKeyFile;
          users.${cfg.user}.password-hash._secret = cfg.passwordHashFile;
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

    selfhost.expose.glance = {
      inherit (cfg) domain port;
      # The dashboard doesn't list itself.
      title = null;
    };
  };
}
