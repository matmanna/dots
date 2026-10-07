# Dawarich (self-hosted Google Location History) at location.matm.icu.
# nginx serves it on :8082 (closed in the firewall); Traefik terminates TLS
# in front via selfhost.expose.
{ config, lib, ... }:
let
  domain = "location.matm.icu";
  port = 8082;
in
{
  age.secrets.dawarich-admin = {
    file = ../../secrets/dawarich-admin.age;
    owner = "dawarich";
  };

  services.dawarich = {
    enable = true;
    localDomain = domain;
    environment = {
      # Generated links and secure cookies use https. Rails forces SSL with
      # this set, so nginx below always tells it the original request was https.
      APPLICATION_PROTOCOL = "https";
      # Reverse geocoding through the public Photon instance (city/country names).
      PHOTON_API_HOST = "photon.komoot.io";
      PHOTON_API_USE_HTTPS = "true";
    };
  };

  services.nginx.virtualHosts.${domain} = {
    listen = [
      {
        addr = "0.0.0.0";
        inherit port;
      }
    ];
    # Location history exports can be several hundred MB.
    extraConfig = "client_max_body_size 2G;";
    # nginx only ever sees plain http from Traefik, so recommendedProxySettings
    # would send X-Forwarded-Proto: http and force_ssl would redirect forever.
    locations."@proxy" = {
      recommendedProxySettings = lib.mkForce false;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
      '';
    };
  };

  # The seeded default admin (demo@dawarich.app) was replaced by hand before
  # this went public; see the dawarich-admin secret. Do the same on a rebuild.
  selfhost.expose.dawarich = {
    inherit domain port;
    title = "dawarich";
    icon = "di:dawarich";
  };
}
