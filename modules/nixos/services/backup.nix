# Nightly restic backup, in the shape of taciturnaxolotl/dots'
# atelier.backup: agenix-held credentials, nightly timer with jitter, prune on
# its own weekly schedule. Instead of per-service data declarations, the k3s
# side is covered wholesale: every CloudNativePG cluster is pg_dumpall'd first,
# then the dumps plus all local-path volumes go up.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.selfhost.backup;
  dumpDir = "/var/lib/selfhost-backup/postgres";
in
{
  options.selfhost.backup = {
    enable = lib.mkEnableOption "nightly restic backups (needs secrets/restic/{env,repo,password}.age)";

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/var/lib/orchard"
        "/var/lib/rancher/k3s/storage"
        dumpDir
      ]
      ++ lib.optional config.services.nextcloud.enable config.services.nextcloud.home
      ++ lib.optional config.services.dawarich.enable "/var/lib/dawarich"
      ++ lib.optional (
        config.services.vaultwarden.enable && config.services.vaultwarden.backupDir != null
      ) config.services.vaultwarden.backupDir;
      description = "Paths to back up.";
    };

    hostDatabases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        lib.optional config.services.nextcloud.enable "nextcloud"
        ++ lib.optional config.services.dawarich.enable config.services.dawarich.database.name;
      description = "Databases on the host's PostgreSQL to pg_dump before each backup.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "*.log"
        "node_modules"
        # Live Postgres data directories; the pg_dumpall output is what restores.
        "/var/lib/rancher/k3s/storage/*/pgdata"
        # Nextcloud thumbnails regenerate on demand.
        "${config.services.nextcloud.home}/data/appdata_*/preview"
      ];
      description = "restic --exclude patterns.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets = {
      "restic/env".file = ../../../secrets/restic/env.age;
      "restic/repo".file = ../../../secrets/restic/repo.age;
      "restic/password".file = ../../../secrets/restic/password.age;
    };

    services.restic.backups.trench = {
      inherit (cfg) paths exclude;
      initialize = true;
      environmentFile = config.age.secrets."restic/env".path;
      repositoryFile = config.age.secrets."restic/repo".path;
      passwordFile = config.age.secrets."restic/password".path;
      extraBackupArgs = [ "--tag nightly" ];
      # Pruning runs from its own weekly unit below.
      pruneOpts = [ ];
      timerConfig = {
        OnCalendar = "03:00";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
      backupPrepareCommand = ''
        set -eu
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        kubectl=${pkgs.k3s}/bin/kubectl
        install -d -m 700 ${dumpDir}
        rm -f ${dumpDir}/*.sql.gz
        $kubectl get clusters.postgresql.cnpg.io -A --no-headers \
          -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name |
          while read -r ns name; do
            pod=$($kubectl -n "$ns" get pod \
              -l "cnpg.io/cluster=$name,cnpg.io/instanceRole=primary" \
              -o jsonpath='{.items[0].metadata.name}')
            echo "dumping $ns/$name from $pod"
            $kubectl -n "$ns" exec "$pod" -c postgres -- pg_dumpall -U postgres |
              ${pkgs.gzip}/bin/gzip > "${dumpDir}/$ns--$name.sql.gz"
          done
      ''
      + lib.concatMapStrings (db: ''
        echo "dumping host postgres: ${db}"
        ${pkgs.util-linux}/bin/runuser -u postgres -- \
          ${config.services.postgresql.package}/bin/pg_dump ${db} |
          ${pkgs.gzip}/bin/gzip > "${dumpDir}/host--${db}.sql.gz"
      '') cfg.hostDatabases;
    };

    systemd.services.restic-prune-trench = {
      description = "Prune old restic snapshots";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.age.secrets."restic/env".path;
      };
      environment = {
        RESTIC_REPOSITORY_FILE = config.age.secrets."restic/repo".path;
        RESTIC_PASSWORD_FILE = config.age.secrets."restic/password".path;
      };
      script = ''
        ${pkgs.restic}/bin/restic forget --prune \
          --keep-daily 7 --keep-weekly 5 --keep-monthly 12
      '';
    };
    systemd.timers.restic-prune-trench = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun 05:00";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}
