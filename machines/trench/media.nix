# Media stack via nixarr, reachable only over Tailscale: nixarr keeps every
# port closed in the firewall and tailscale0 is a trusted interface.
#   jellyfin  http://trench:8096
#   sonarr    http://trench:8989
#   radarr    http://trench:7878
#   prowlarr  http://trench:9696
#   seerr     http://trench:5055   (browse + request, Jellyfin logins)
#   bazarr    http://trench:6767   (fetches missing subtitles)
#   flaresolverr http://localhost:8191 (Prowlarr indexer proxy for
#                Cloudflare-protected indexers; not reachable from outside)
#   qbittorrent http://trench:5252 (qui)
# qBittorrent runs only inside an AirVPN WireGuard tunnel (nixarr.vpn, its
# own network namespace, so no traffic can leave outside the VPN):
# torrenting from Contabo's own IP risks the whole VPS. Port 7208 is
# forwarded to it by AirVPN.
# The library moves to the Hetzner Storage Box once that exists.
{ config, pkgs, ... }:
let
  keyFile = app: "/data/.state/nixarr/secrets/${app}.api-key";
in
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
    bazarr.enable = true;

    # TRaSH Guides quality profiles and custom formats, synced daily. API
    # keys come from nixarr's own extracted copies.
    recyclarr = {
      enable = true;
      configuration = {
        # Mirrors recyclarr's official v8 templates "web-1080p" and
        # "hd-bluray-web" (github.com/recyclarr/config-templates).
        sonarr.series = {
          base_url = "http://localhost:8989";
          api_key = "!env_var SONARR_API_KEY";
          quality_definition.type = "series";
          quality_profiles = [
            {
              trash_id = "72dae194fc92bf828f32cde7744e51a1"; # WEB-1080p
              reset_unmatched_scores.enabled = true;
            }
          ];
          custom_format_groups.add = [
            { trash_id = "158188097a58d7687dee647e04af0da3"; } # [Optional] Golden Rule HD
            { trash_id = "85fae4a2294965b75710ef2989c850eb"; } # [Streaming Services] HD/UHD boost
            { trash_id = "59c3af66780d08332fdc64e68297098f"; } # [Unwanted] Unwanted Formats
          ];
        };
        radarr.movies = {
          base_url = "http://localhost:7878";
          api_key = "!env_var RADARR_API_KEY";
          quality_definition.type = "movie";
          quality_profiles = [
            {
              trash_id = "d1d67249d3890e49bc12e275d989a7e9"; # HD Bluray + WEB
              reset_unmatched_scores.enabled = true;
            }
          ];
          custom_format_groups.add = [
            { trash_id = "f8bf8eab4617f12dfdbd16303d8da245"; } # [Optional] Golden Rule HD
            { trash_id = "a3ac6af01d78e4f21fcb75f601ac96df"; } # [Unwanted] Unwanted Formats
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
          title = "bazarr";
          icon = "di:bazarr";
          port = 6767;
        }
        {
          title = "qbittorrent";
          icon = "di:qbittorrent";
          port = 5252;
        }
      ];

  services.flaresolverr.enable = true;

  # Each FlareSolverr attempt runs a headless Chrome flat out for up to a
  # minute; failing indexers retry all day. Cap it so it can never starve
  # Tailscale or the apps (it once pushed trench to ~90% CPU).
  systemd.services.flaresolverr.serviceConfig = {
    CPUQuota = "100%";
    CPUWeight = 20;
    MemoryMax = "2G";
    Nice = 10;
  };

  # Background batch jobs yield to interactive services.
  systemd.services.recyclarr.serviceConfig.CPUWeight = 20;

  # Torrent status on the dashboard. qBittorrent's API needs no login from
  # the host side of the VPN namespace (nixarr whitelists 192.168.15.0/24).
  # Sonarr's calendar wants explicit dates, which Glance can't compute, so a
  # timer fetches the next 7 days into the dashboard's assets dir.
  systemd.services.dashboard-upcoming = {
    description = "Fetch upcoming episodes from Sonarr for the dashboard";
    after = [ "sonarr.service" ];
    path = [
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      CPUWeight = 20;
    };
    script = ''
      key=$(cat ${keyFile "sonarr"})
      start=$(date -u +%Y-%m-%d)
      end=$(date -u -d '+7 days' +%Y-%m-%d)
      curl -sf -H "X-Api-Key: $key" \
        "http://localhost:8989/api/v3/calendar?start=$start&end=$end&includeSeries=true" \
        | jq '{episodes: [.[] | {
            series: .series.title,
            code: ("S" + (.seasonNumber | tostring | if length < 2 then "0" + . else . end)
                 + "E" + (.episodeNumber | tostring | if length < 2 then "0" + . else . end)),
            title, airDateUtc, hasFile }]}' \
        > /var/lib/selfhost-dashboard/upcoming.json.tmp
      mv /var/lib/selfhost-dashboard/upcoming.json.tmp /var/lib/selfhost-dashboard/upcoming.json
    '';
  };
  systemd.timers.dashboard-upcoming = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
    };
  };

  selfhost.dashboard.extraWidgets = [
    {
      type = "custom-api";
      title = "downloads";
      cache = "1m";
      url = "http://localhost:8989/api/v3/queue?pageSize=10&includeSeries=true&includeEpisode=true";
      headers."X-Api-Key"._secret = keyFile "sonarr";
      subrequests.radarr = {
        url = "http://localhost:7878/api/v3/queue?pageSize=10&includeMovie=true";
        headers."X-Api-Key"._secret = keyFile "radarr";
      };
      template = ''
        {{ $movies := .Subrequest "radarr" }}
        {{ if and (eq (.JSON.Int "totalRecords") 0) (eq ($movies.JSON.Int "totalRecords") 0) }}
          <p class="color-subdue">nothing downloading</p>
        {{ else }}
        <ul class="list list-gap-8">
        {{ range .JSON.Array "records" }}
          <li class="flex justify-between">
            <span class="text-truncate">{{ .String "series.title" }} · S{{ printf "%02d" (.Int "episode.seasonNumber") }}E{{ printf "%02d" (.Int "episode.episodeNumber") }}</span>
            <span class="color-highlight">{{ if gt (.Float "size") 0.0 }}{{ printf "%.0f" (mul (sub 1.0 (div (.Float "sizeleft") (.Float "size"))) 100) }}%{{ end }} · {{ .String "status" }}</span>
          </li>
        {{ end }}
        {{ range $movies.JSON.Array "records" }}
          <li class="flex justify-between">
            <span class="text-truncate">{{ .String "movie.title" }} ({{ .Int "movie.year" }})</span>
            <span class="color-highlight">{{ if gt (.Float "size") 0.0 }}{{ printf "%.0f" (mul (sub 1.0 (div (.Float "sizeleft") (.Float "size"))) 100) }}%{{ end }} · {{ .String "status" }}</span>
          </li>
        {{ end }}
        </ul>
        {{ end }}
      '';
    }
    {
      type = "custom-api";
      title = "upcoming episodes";
      cache = "15m";
      url = "http://127.0.0.1:${toString config.selfhost.dashboard.port}/assets/upcoming.json";
      template = ''
        {{ $eps := .JSON.Array "episodes" }}
        {{ if eq (len $eps) 0 }}
          <p class="color-subdue">nothing airing in the next 7 days</p>
        {{ else }}
        <ul class="list list-gap-8">
        {{ range $eps }}
          <li class="flex justify-between">
            <span class="text-truncate">{{ .String "series" }} · {{ .String "code" }}</span>
            <span class="color-highlight" {{ .String "airDateUtc" | parseTime "rfc3339" | toRelativeTime }}></span>
          </li>
        {{ end }}
        </ul>
        {{ end }}
      '';
    }
    {
      type = "custom-api";
      title = "torrents";
      cache = "1m";
      url = "http://192.168.15.1:8085/api/v2/torrents/info?sort=added_on&reverse=true&limit=8";
      subrequests.transfer.url = "http://192.168.15.1:8085/api/v2/transfer/info";
      template = ''
        {{ $t := .Subrequest "transfer" }}
        <div class="flex justify-between margin-bottom-10">
          <span class="size-h5">{{ $t.JSON.String "connection_status" }} · {{ $t.JSON.String "last_external_address_v4" }}</span>
          <span class="color-highlight">↓ {{ printf "%.1f" (div ($t.JSON.Float "dl_info_speed") 1048576) }} · ↑ {{ printf "%.1f" (div ($t.JSON.Float "up_info_speed") 1048576) }} MB/s</span>
        </div>
        <ul class="list list-gap-8">
        {{ range .JSON.Array "" }}
          <li>
            <div class="text-truncate">{{ .String "name" }}</div>
            <div class="flex justify-between size-h6">
              <span>{{ .String "state" }}</span>
              <span class="color-highlight">{{ printf "%.0f" (mul (.Float "progress") 100) }}% · ↓ {{ printf "%.1f" (div (.Float "dlspeed") 1048576) }} MB/s</span>
            </div>
          </li>
        {{ end }}
        </ul>
      '';
    }
  ];
}
