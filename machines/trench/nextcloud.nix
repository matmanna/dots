# Nextcloud at cloud.matm.icu. nginx serves it on :8081 (closed in the
# firewall) and k3s's Traefik terminates TLS in front via selfhost.expose.
{ config, pkgs, ... }:
let
  domain = "cloud.matm.icu";
  port = 8081;
in
{
  age.secrets.nextcloud-admin = {
    file = ../../secrets/nextcloud-admin.age;
    owner = "nextcloud";
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud35;
    hostName = domain;
    # Generated links use https; TLS itself ends at Traefik.
    https = true;

    database.createLocally = true;
    configureRedis = true;
    maxUploadSize = "16G";

    config = {
      dbtype = "pgsql";
      adminuser = "admin";
      adminpassFile = config.age.secrets.nextcloud-admin.path;
    };

    extraApps = {
      inherit (config.services.nextcloud.package.packages.apps)
        calendar
        contacts
        notes
        tasks
        ;
    };
    extraAppsEnable = true;

    settings = {
      # Traefik runs on the pod network and forwards the client address.
      trusted_proxies = [ "10.42.0.0/16" ];
      overwriteprotocol = "https";
      default_phone_region = "US";
      # Heavy background jobs at 01:00-05:00 UTC.
      maintenance_window_start = 1;
      log_type = "file";
    };

    phpOptions."opcache.interned_strings_buffer" = "16";
  };

  services.nginx.virtualHosts.${domain}.listen = [
    {
      addr = "0.0.0.0";
      inherit port;
    }
  ];

  selfhost.exposeHostAddress = "157.173.116.9";
  selfhost.expose.nextcloud = { inherit domain port; };
}
