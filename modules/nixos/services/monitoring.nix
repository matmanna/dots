# Netdata: per-service CPU/RAM/disk/network history for every systemd unit
# (k3s pods show up under kubepods). Listens on localhost; `tailscale serve`
# publishes it on the tailnet only.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.selfhost.monitoring;

  # Netdata's per-service RAM and CPU series -> top 12 services by RAM.
  topServicesJq = pkgs.writeText "top-services.jq" ''
    def series(d):
      [d.result.labels[1:], d.result.data[0][1:]]
      | transpose
      | map({
          key: (.[0] | sub("^systemd_"; "") | sub("\\.(mem|cpu)@.*$"; "")),
          value: (if (.[1] | type) == "array" then .[1][0] else .[1] end)
        })
      | from_entries;
    series($m) as $mem
    | series($c) as $cpu
    | {
        services: (
          [ $mem | to_entries[]
            | { name: .key,
                ram: (.value | floor),
                cpu: ((($cpu[.key] // 0) * 10 | round) / 10) } ]
          | sort_by(-.ram)
          | .[:12]
        )
      }
  '';
in
{
  options.selfhost.monitoring = {
    enable = lib.mkEnableOption "Netdata, tailnet-only";
    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 19999;
      description = "Tailnet HTTPS port tailscale serve publishes Netdata on.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "netdata";

    # Top services by RAM (with CPU) as a small JSON file the dashboard reads.
    # Glance can't sort API data itself, so jq does it here once a minute.
    systemd.services.netdata-top-services = {
      description = "Write top services by RAM/CPU for the dashboard";
      after = [ "netdata.service" ];
      path = [
        pkgs.curl
        pkgs.jq
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        q='after=-60&points=1&time_group=average&group_by=instance&format=json2'
        api=http://127.0.0.1:19998/api/v3/data
        mem=$(curl -sf "$api?contexts=systemd.service.memory.ram.usage&$q")
        cpu=$(curl -sf "$api?contexts=systemd.service.cpu.utilization&$q")
        install -d -m 755 /var/lib/selfhost-dashboard
        out=/var/lib/selfhost-dashboard/top-services.json
        jq -n --argjson m "$mem" --argjson c "$cpu" -f ${topServicesJq} > "$out.tmp"
        mv "$out.tmp" "$out"
      '';
    };
    systemd.timers.netdata-top-services = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1min";
      };
    };

    services.netdata = {
      enable = true;
      # Includes the web dashboard (Netdata's NCUL1 license, not open source);
      # the default package has no UI at all.
      package = pkgs.netdataCloud;
      config = {
        web."bind to" = "127.0.0.1:19998";
        global."memory mode" = "dbengine";
        # No phoning home.
        global."anonymous statistics" = "no";
      };
    };

    systemd.services.netdata-tailscale-serve = {
      description = "Publish Netdata on the tailnet with tailscale serve";
      wantedBy = [ "multi-user.target" ];
      after = [
        "tailscaled.service"
        "netdata.service"
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
        tailscale serve --bg --https=${toString cfg.httpsPort} http://127.0.0.1:19998
      '';
    };
  };
}
