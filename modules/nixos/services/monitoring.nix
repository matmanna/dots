# Per-app CPU/RAM for the dashboard, without a monitoring daemon: a
# one-minute timer samples the kernel's cgroup counters for every systemd
# service (CPU time over 5 s, anonymous memory, i.e. excluding file cache) and `kubectl top` for k3s pods,
# and writes the top entries as JSON that Glance reads from /assets.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.selfhost.monitoring;
  dir = "/var/lib/selfhost-dashboard";

  sample = pkgs.writeShellScript "dashboard-usage" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.jq
        pkgs.k3s
      ]
    }
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    # name usage_usec memory_bytes, for every system.slice/*.service
    snap() {
      for d in /sys/fs/cgroup/system.slice/*.service; do
        [ -r "$d/cpu.stat" ] || continue
        printf '%s %s %s\n' "$(basename "$d" .service)" \
          "$(awk '$1 == "usage_usec" { print $2 }' "$d/cpu.stat")" \
          "$(awk '$1 == "anon" { print $2 }' "$d/memory.stat" 2>/dev/null || echo 0)"
      done
    }

    a=$(snap); sleep 5; b=$(snap)

    # CPU as % of one core over the 5 s window; RAM in MiB.
    services=$(awk -v interval=5000000 '
      NR == FNR { before[$1] = $2; next }
      ($1 in before) {
        printf "%s %.1f %d\n", $1, ($2 - before[$1]) * 100 / interval, $3 / 1048576
      }' <(echo "$a") <(echo "$b") \
      | jq -R -s '[split("\n")[] | select(length > 0) | split(" ")
          | {name: .[0], cpu: (.[1] | tonumber), ram: (.[2] | tonumber)}]
          | sort_by(-.ram) | .[:12]')

    # NAMESPACE NAME CPU(m) MEMORY(Mi) -> app name without the hash suffixes.
    pods=$(kubectl top pods -A --no-headers 2>/dev/null \
      | jq -R -s '[split("\n")[] | select(length > 0) | [splits(" +")]
          | {name: (.[1] | sub("-[a-z0-9]{8,10}-[a-z0-9]{5}$"; "") | sub("-[a-z0-9]{5}$"; "")),
             cpu: (.[2] | rtrimstr("m") | tonumber / 10),
             ram: (.[3] | rtrimstr("Mi") | tonumber)}]
          | sort_by(-.ram) | .[:12]' || echo '[]')

    jq -n --argjson s "$services" --argjson p "$pods" '{services: $s, pods: $p}' \
      > ${dir}/usage.json.tmp
    mv ${dir}/usage.json.tmp ${dir}/usage.json
  '';
in
{
  options.selfhost.monitoring.enable = lib.mkEnableOption "per-app usage stats for the dashboard";

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${dir} 0755 root root -" ];

    systemd.services.dashboard-usage = {
      description = "Sample per-service and per-pod CPU/RAM for the dashboard";
      after = [ "k3s.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = sample;
        CPUWeight = 20;
      };
    };
    systemd.timers.dashboard-usage = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
      };
    };
  };
}
