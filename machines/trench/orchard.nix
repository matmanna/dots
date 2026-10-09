# Orchard on top of the k3s platform layer in ./k3s.nix. Mirrors what
# https://assets.orchard.my/install.sh does in `public` mode, but declaratively.
#
# Secrets are generated once on the host into /var/lib/orchard/secrets.env and
# never enter the Nix store. Back that file up: losing SECRETS_ENCRYPTION_KEY
# makes every secret stored in Orchard's database unreadable.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.selfhost.orchard;
  domain = "orchard.matm.icu";
  appDomain = "apps.matm.icu";
  mcpDomain = "mcp.matm.icu";
  acmeEmail = "vps@matmanna.dev";

  chartVersion = "2.54.0";
  registryHost = "registry.orchard.local";
  registryPort = 5000;
  registryUser = "orchard";

  # Sized the way install.sh sizes a 23Gi / 300G box.
  maxBuilds = 3;
  buildCacheGi = 59;
  registryGi = 50;

  yaml = pkgs.formats.yaml { };
  env = name: value: { inherit name value; };

  chart =
    pkgs.runCommand "orchard-${chartVersion}.tgz"
      {
        outputHash = "sha256-HpRlJWCybxv6dTjIHTqVx7av0YGD4OcS+dQ+aadMX2M=";
        outputHashAlgo = null;
        impureEnvVars = lib.fetchers.proxyImpureEnvVars;
        nativeBuildInputs = [
          pkgs.kubernetes-helm
          pkgs.cacert
          pkgs.writableTmpDirAsHomeHook
        ];
      }
      ''
        helm pull oci://ghcr.io/hackclub/orchard/charts/orchard --version ${chartVersion}
        mv ./*.tgz $out
      '';

  tlsIssuer = {
    enabled = true;
    issuerRef = {
      name = "letsencrypt";
      kind = "ClusterIssuer";
    };
  };

  # ''${VAR} placeholders are filled from secrets.env by envsubst at deploy time.
  valuesTemplate = yaml.generate "orchard-values.yaml" {
    createNamespace = false;
    image = {
      registry = "ghcr.io";
      repository = "hackclub/orchard";
      pullPolicy = "Always";
    };
    signupMode = "invite_only";
    datadog.enabled = false;

    frontend = {
      replicas = 1;
      image.tag = "latest";
      env = [
        (env "PUBLIC_APP_DOMAIN" appDomain)
        (env "PUBLIC_HTTP_PORT" "80")
        (env "PUBLIC_HTTPS_PORT" "443")
        (env "PUBLIC_OAUTH_PROVIDER" "none")
      ];
    };

    server = {
      replicas = 1;
      image.tag = "latest";
      env = [
        (env "JWT_SECRET" "\${JWT_SECRET}")
        (env "SECRETS_ENCRYPTION_KEY" "\${SECRETS_ENCRYPTION_KEY}")
        (env "SSO_ENCRYPTION_KEY" "\${SSO_ENCRYPTION_KEY}")
        (env "MCP_SERVICE_TOKEN" "\${MCP_SERVICE_TOKEN}")
        (env "APP_DOMAIN" appDomain)
        (env "PUBLIC_HTTP_PORT" "80")
        (env "PUBLIC_HTTPS_PORT" "443")
        (env "FRONTEND_URL" "https://${domain}")
        (env "SESSION_COOKIE_SECURE" "true")
        (env "MAX_CONCURRENT_BUILDS" (toString maxBuilds))
        (env "DOCKER_REGISTRY_PUSH" "zot.orchard.svc.cluster.local:5000")
        (env "DOCKER_REGISTRY_PULL" registryHost)
        (env "REGISTRY_HTTP_HOSTS" "zot.orchard.svc.cluster.local:5000")
        (env "REGISTRY_PROJECT" "orchard")
        (env "HARBOR_USERNAME" registryUser)
        (env "HARBOR_PASSWORD" "\${REGISTRY_PASSWORD}")
        (env "BUILDER_SCRATCH_STORAGE_CLASS" "local-path")
      ];
    };

    tenant = {
      ingressNamespaces = "traefik,orchard";
      storageClass = "local-path";
      ingressClass = "traefik";
      certClusterIssuer = "letsencrypt";
    };

    ingress = {
      enabled = true;
      host = domain;
      extraHosts = [ ];
      entryPoints = [ "websecure" ];
      tls = tlsIssuer;
    };

    gateway = {
      enabled = true;
      namespace = "network";
      gatewayClassName = "traefik";
      http = {
        enabled = false;
        inherit appDomain;
      };
    };

    postgres = {
      enabled = true;
      instances = 1;
      storage = {
        size = "10Gi";
        storageClass = "local-path";
      };
    };

    redis = {
      enabled = true;
      storage = "1Gi";
      storageClass = "local-path";
    };

    builders = {
      enabled = true;
      harbor = {
        username = registryUser;
        password = "\${REGISTRY_PASSWORD}";
        hosts = [ "zot.orchard.svc.cluster.local:5000" ];
      };
      httpRegistries = [ "zot.orchard.svc.cluster.local:5000" ];
      registryEgress = [
        {
          namespace = "orchard";
          podLabels.app = "zot";
          ports = [ { port = 5000; } ];
        }
      ];
      localCache = {
        enabled = true;
        size = "${toString buildCacheGi}Gi";
        storageClass = "local-path";
      };
    };

    metrics = {
      # Off for now to save CPU on trench (VictoriaMetrics, vmagent,
      # kube-state-metrics, node-exporter and their API polling). Orchard's
      # per-app charts go away; Glance's pods widget still shows usage.
      enabled = false;
      victoriametrics = {
        retention = "7d";
        storage = {
          size = "5Gi";
          storageClass = "local-path";
        };
      };
    };

    mcp = {
      enabled = true;
      url = "https://${mcpDomain}";
      ingress = {
        enabled = true;
        host = mcpDomain;
        entryPoints = [ "websecure" ];
        tls = tlsIssuer;
      };
      env = [
        (env "JWT_SECRET" "\${JWT_SECRET}")
        (env "MCP_SERVICE_TOKEN" "\${MCP_SERVICE_TOKEN}")
      ];
    };

    certificates.enabled = false;
    r2Proxy.enabled = false;
    tenantSandbox.enabled = false;
    builderSandbox.enabled = false;
    sandbox.enabled = false;
  };

  clusterIssuer = yaml.generate "letsencrypt-issuer.yaml" {
    apiVersion = "cert-manager.io/v1";
    kind = "ClusterIssuer";
    metadata.name = "letsencrypt";
    spec.acme = {
      server = "https://acme-v02.api.letsencrypt.org/directory";
      email = acmeEmail;
      privateKeySecretRef.name = "letsencrypt-account-key";
      solvers = [ { http01.ingress.class = "traefik"; } ];
    };
  };

  # zot registry for images Orchard builds; loopback hostPort only, as in install.sh.
  zot = pkgs.writeText "zot.yaml" ''
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: zot-data
      namespace: orchard
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: local-path
      resources:
        requests:
          storage: ${toString registryGi}Gi
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: zot-config
      namespace: orchard
    data:
      config.json: |
        {
          "storage": {
            "rootDirectory": "/var/lib/registry",
            "gc": true,
            "gcDelay": "1h",
            "gcInterval": "24h"
          },
          "http": {
            "address": "0.0.0.0",
            "port": "5000",
            "auth": { "htpasswd": { "path": "/etc/zot-auth/htpasswd" } }
          },
          "log": { "level": "info" },
          "extensions": {
            "scrub": { "interval": "24h" }
          }
        }
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: zot
      namespace: orchard
    spec:
      replicas: 1
      strategy: { type: Recreate }
      selector:
        matchLabels: { app: zot }
      template:
        metadata:
          labels: { app: zot }
        spec:
          containers:
            - name: zot
              image: ghcr.io/project-zot/zot-linux-amd64:latest
              args: ["serve", "/etc/zot/config.json"]
              ports:
                - containerPort: 5000
                  hostPort: ${toString registryPort}
                  hostIP: 127.0.0.1
              volumeMounts:
                - { name: data, mountPath: /var/lib/registry }
                - { name: config, mountPath: /etc/zot }
                - { name: auth, mountPath: /etc/zot-auth, readOnly: true }
              resources:
                requests: { cpu: 50m, memory: 64Mi }
                limits: { cpu: "1", memory: 512Mi }
          volumes:
            - name: data
              persistentVolumeClaim: { claimName: zot-data }
            - name: config
              configMap: { name: zot-config }
            - name: auth
              secret: { secretName: zot-auth }
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: zot
      namespace: orchard
    spec:
      type: ClusterIP
      selector: { app: zot }
      ports:
        - port: 5000
          targetPort: 5000
  '';
in
{
  options.selfhost.orchard.secretsFromAgenix = lib.mkEnableOption ''
    taking Orchard's secrets from secrets/orchard.age instead of generating
    them on the host. Encrypt the existing /var/lib/orchard/secrets.env first,
    or every stored secret becomes unreadable
  '';

  config = {
    age.secrets = lib.mkIf cfg.secretsFromAgenix {
      orchard.file = ../../secrets/orchard.age;
    };

    # Runs before k3s so the registry mirror config exists when containerd starts.
    systemd.services.orchard-secrets = {
      description = "Generate Orchard secrets and k3s registry mirror config";
      wantedBy = [ "k3s.service" ];
      after = [ "agenix.service" ];
      before = [ "k3s.service" ];
      path = [
        pkgs.coreutils
        pkgs.apacheHttpd
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      script = ''
        dir=/var/lib/orchard
        install -d -m 700 "$dir"
        rand() { head -c "$1" /dev/urandom | base64 | tr -d '\n=' | head -c "$2"; }

        ${lib.optionalString cfg.secretsFromAgenix ''
          install -m 600 ${config.age.secrets.orchard.path} "$dir/secrets.env"
        ''}
        if [ ! -s "$dir/secrets.env" ]; then
          cat > "$dir/secrets.env" <<EOF
        JWT_SECRET=$(rand 32 43)
        SECRETS_ENCRYPTION_KEY=$(rand 24 32)
        SSO_ENCRYPTION_KEY=$(rand 24 32)
        MCP_SERVICE_TOKEN=$(rand 32 43)
        REGISTRY_PASSWORD=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')
        EOF
        fi
        . "$dir/secrets.env"

        if [ ! -s "$dir/htpasswd" ]; then
          htpasswd -nbB ${registryUser} "$REGISTRY_PASSWORD" | grep '^${registryUser}:' > "$dir/htpasswd"
        fi

        install -d -m 755 /etc/rancher/k3s
        cat > /etc/rancher/k3s/registries.yaml <<EOF
        mirrors:
          ${registryHost}:
            endpoint:
              - "http://127.0.0.1:${toString registryPort}"
        configs:
          "127.0.0.1:${toString registryPort}":
            auth:
              username: ${registryUser}
              password: "$REGISTRY_PASSWORD"
        EOF
      '';
    };

    systemd.services.orchard-deploy = {
      description = "Deploy Orchard Helm release";
      wantedBy = [ "multi-user.target" ];
      after = [
        "k3s.service"
        "orchard-secrets.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      requires = [
        "k3s.service"
        "orchard-secrets.service"
      ];
      environment = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
        HOME = "/var/lib/orchard";
      };
      path = [
        pkgs.coreutils
        pkgs.k3s
        pkgs.kubernetes-helm
        pkgs.gettext
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
        TimeoutStartSec = "45min";
        Restart = "on-failure";
        RestartSec = "30s";
      };
      startLimitIntervalSec = 0;
      script = ''
        set -euo pipefail
        wait_for() {
          local tries=0
          until "$@" >/dev/null 2>&1; do
            tries=$((tries + 1))
            [ "$tries" -lt 300 ] || { echo "timed out: $*" >&2; return 1; }
            sleep 3
          done
        }

        wait_for kubectl get --raw /readyz
        for crd in \
          gateways.gateway.networking.k8s.io \
          ingressroutes.traefik.io \
          clusters.postgresql.cnpg.io \
          clusterissuers.cert-manager.io; do
          wait_for kubectl get crd "$crd"
          # A just-created CRD has no status yet, and kubectl wait errors on that.
          wait_for kubectl wait --for=condition=Established "crd/$crd" --timeout=10s
        done
        wait_for kubectl -n cert-manager get deploy/cert-manager-webhook
        kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=10m
        wait_for kubectl -n cnpg-system get deploy/cloudnative-pg
        kubectl -n cnpg-system rollout status deploy/cloudnative-pg --timeout=10m

        kubectl apply -f ${clusterIssuer}
        for ns in orchard network; do
          kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
        done
        kubectl -n orchard create secret generic zot-auth \
          --from-file=htpasswd=/var/lib/orchard/htpasswd \
          --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f ${zot}
        kubectl -n orchard rollout status deploy/zot --timeout=5m

        set -a
        . /var/lib/orchard/secrets.env
        set +a
        values=$(mktemp)
        trap 'rm -f "$values"' EXIT
        envsubst '$JWT_SECRET $SECRETS_ENCRYPTION_KEY $SSO_ENCRYPTION_KEY $MCP_SERVICE_TOKEN $REGISTRY_PASSWORD' \
          < ${valuesTemplate} > "$values"

        helm upgrade --install orchard ${chart} \
          --namespace orchard -f "$values" --timeout 20m

        kubectl -n orchard wait --for=condition=Ready cluster.postgresql.cnpg.io/orchard-db --timeout=15m
        kubectl -n orchard rollout status deploy/redis --timeout=5m
        kubectl -n orchard rollout status deploy/server --timeout=10m
        kubectl -n orchard rollout status deploy/frontend --timeout=5m
        kubectl -n orchard rollout status deploy/mcp --timeout=5m
      '';
    };
  };
}
