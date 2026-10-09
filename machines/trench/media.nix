# Media stack via nixarr, reachable only over Tailscale: nixarr keeps every
# port closed in the firewall and tailscale0 is a trusted interface.
#   jellyfin  http://trench:8096
#   sonarr    http://trench:8989
#   radarr    http://trench:7878
#   prowlarr  http://trench:9696
# qBittorrent stays off until it can run inside the Mullvad WireGuard tunnel
# (nixarr.vpn): torrenting from Contabo's own IP risks the whole VPS.
# The library moves to the Hetzner Storage Box once that exists.
{
  nixarr = {
    enable = true;
    mediaDir = "/data/media";
    stateDir = "/data/.state/nixarr";

    jellyfin.enable = true;
    prowlarr.enable = true;
    sonarr.enable = true;
    radarr.enable = true;
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
      ];
}
