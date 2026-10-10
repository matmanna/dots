# Nextcloud at cloud.matm.icu. nginx serves it on :8081 (closed in the
# firewall) and k3s's Traefik terminates TLS in front via selfhost.expose.
{
  config,
  lib,
  pkgs,
  ...
}:
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

  # serverinfo API token for the dashboard's storage widget.
  age.secrets.nextcloud-serverinfo.file = ../../secrets/nextcloud-serverinfo.age;
  systemd.services.nextcloud-serverinfo-token = {
    description = "Set Nextcloud's serverinfo API token";
    after = [ "nextcloud-setup.service" ];
    requires = [ "nextcloud-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ config.age.secrets.nextcloud-serverinfo.file ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${lib.getExe config.services.nextcloud.occ} config:app:set serverinfo token \
        --value "$(cat ${config.age.secrets.nextcloud-serverinfo.path})" >/dev/null
    '';
  };

  selfhost.dashboard.sideWidgets = [
    {
      type = "custom-api";
      title = "nextcloud";
      cache = "10m";
      url = "https://${domain}/ocs/v2.php/apps/serverinfo/api/v1/info?format=json&skipApps=false&skipUpdate=true";
      headers."NC-Token"._secret = config.age.secrets.nextcloud-serverinfo.path;
      template = ''
        {{ $nc := "ocs.data.nextcloud" }}
        <ul class="list list-gap-4">
          <li class="flex justify-between"><span>files</span><span class="color-highlight">{{ .JSON.Int (print $nc ".storage.num_files") }}</span></li>
          <li class="flex justify-between"><span>users</span><span class="color-highlight">{{ .JSON.Int (print $nc ".storage.num_users") }}</span></li>
          <li class="flex justify-between"><span>active today</span><span class="color-highlight">{{ .JSON.Int "ocs.data.activeUsers.last24hours" }}</span></li>
          <li class="flex justify-between"><span>free space</span><span class="color-highlight">{{ printf "%.0f" (div (.JSON.Float (print $nc ".system.freespace")) 1073741824) }} GiB</span></li>
          <li class="flex justify-between"><span>app updates</span><span class="color-highlight">{{ .JSON.Int (print $nc ".system.apps.num_updates_available") }}</span></li>
        </ul>
      '';
    }
  ];

  services.nginx.virtualHosts.${domain}.listen = [
    {
      addr = "0.0.0.0";
      inherit port;
    }
  ];

  selfhost.exposeHostAddress = "157.173.116.9";
  selfhost.expose.nextcloud = {
    inherit domain port;
    title = "nextcloud";
    icon = "di:nextcloud";
  };
}
