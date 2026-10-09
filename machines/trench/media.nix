# Media stack via nixarr, reachable only over Tailscale: nixarr keeps every
# port closed in the firewall and tailscale0 is a trusted interface.
#   jellyfin  http://trench:8096
#   sonarr    http://trench:8989
#   radarr    http://trench:7878
#   prowlarr  http://trench:9696
#   seerr     http://trench:5055   (browse + request, Jellyfin logins)
#   flaresolverr http://localhost:8191 (Prowlarr indexer proxy for
#                Cloudflare-protected indexers; not reachable from outside)
#   qbittorrent http://trench:5252 (qui)
# qBittorrent runs only inside an AirVPN WireGuard tunnel (nixarr.vpn, its
# own network namespace, so no traffic can leave outside the VPN):
# torrenting from Contabo's own IP risks the whole VPS. Port 7208 is
# forwarded to it by AirVPN.
# The library moves to the Hetzner Storage Box once that exists.
{ config, ... }:
{
  age.secrets.airvpn-trench.file = ../../secrets/airvpn-trench.age;

  nixarr = {
    enable = true;
    mediaDir = "/data/media";
    stateDir = "/data/.state/nixarr";

    jellyfin.enable = true;
    prowlarr.enable = true;
    sonarr.enable = true;
    radarr.enable = true;
    seerr.enable = true;

    # TRaSH Guides quality profiles and custom formats, synced daily. API
    # keys come from nixarr's own extracted copies.
    recyclarr = {
      enable = true;
      configuration = {
        sonarr.series = {
          base_url = "http://localhost:8989";
          api_key = "!env_var SONARR_API_KEY";
          include = [
            { template = "sonarr-quality-definition-series"; }
            { template = "sonarr-v4-quality-profile-web-1080p"; }
            { template = "sonarr-v4-custom-formats-web-1080p"; }
          ];
        };
        radarr.movies = {
          base_url = "http://localhost:7878";
          api_key = "!env_var RADARR_API_KEY";
          include = [
            { template = "radarr-quality-definition-movie"; }
            { template = "radarr-quality-profile-hd-bluray-web"; }
            { template = "radarr-custom-formats-hd-bluray-web"; }
          ];
        };
      };
    };

    vpn = {
      enable = true;
      wgConf = config.age.secrets.airvpn-trench.path;
    };

    qbittorrent = {
      enable = true;
      vpn.enable = true;
      peerPort = 7208;
      # qui (nixarr's default web UI) serves :5252 on the host and talks to
      # qBittorrent inside the namespace at 192.168.15.1:8085.
      webuiPort = 5252;
    };
  };

  selfhost.dashboard.extraSites =
    map
      (s: {
        inherit (s) title icon;
        url = "http://trench.tail4a3e06.ts.net:${toString s.port}";
      })
      [
        {
          title = "jellyfin";
          icon = "di:jellyfin";
          port = 8096;
        }
        {
          title = "sonarr";
          icon = "di:sonarr";
          port = 8989;
        }
        {
          title = "radarr";
          icon = "di:radarr";
          port = 7878;
        }
        {
          title = "prowlarr";
          icon = "di:prowlarr";
          port = 9696;
        }
        {
          title = "seerr";
          icon = "di:jellyseerr";
          port = 5055;
        }
        {
          title = "qbittorrent";
          icon = "di:qbittorrent";
          port = 5252;
        }
      ];

  services.flaresolverr.enable = true;
}
