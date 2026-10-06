# k3s plus the platform layer Orchard's install.sh would otherwise set up:
# Gateway API CRDs, Traefik, CloudNativePG and cert-manager. These are
# reconciled by k3s's helm-controller from /var/lib/rancher/k3s/server/manifests.
{ pkgs, ... }:
{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable=traefik"
      "--write-kubeconfig-mode=600"
      "--service-node-port-range=30000-30100"
    ];

    manifests.gateway-api-crds.source = pkgs.fetchurl {
      url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml";
      hash = "sha256-l1mL9qs7M7m1xUMr3STeCR5OnDqgV167BxCioZzWTWQ=";
    };

    autoDeployCharts = {
      # Not "traefik": k3s stages its own bundled traefik.yaml under that name.
      traefik-ingress = {
        name = "traefik";
        repo = "https://traefik.github.io/charts";
        version = "41.6.1";
        hash = "sha256-HmXUa64LoLrvRgodgmhrUPFWNyhlo9fYqFtRw4VbLvk=";
        targetNamespace = "traefik";
        createNamespace = true;
        # Same flags as install.sh in public mode. LoadBalancer means k3s
        # servicelb binds 80/443 on the node.
        values = {
          # Orchard tenant ingresses and the ACME solver use class "traefik";
          # the chart would otherwise name it after the release.
          ingressClass.name = "traefik";
          providers.kubernetesGateway.enabled = true;
          gateway.enabled = false;
          service.spec.type = "LoadBalancer";
          ports.web.exposedPort = 80;
          # Everything on :80 goes to https, except cert-manager's HTTP-01
          # solver, which allowACMEByPass lets answer before the redirect.
          ports.web.allowACMEByPass = true;
          ports.web.http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
            permanent = true;
          };
          ports.websecure.exposedPort = 443;
        };
      };

      cloudnative-pg = {
        name = "cloudnative-pg";
        repo = "https://cloudnative-pg.github.io/charts";
        version = "0.29.1";
        hash = "sha256-tT05kf6EvPOHZ+dwLK54ZmJlQnoSeib/8WirQgfSsd8=";
        targetNamespace = "cnpg-system";
        createNamespace = true;
      };

      cert-manager = {
        name = "cert-manager";
        repo = "https://charts.jetstack.io";
        version = "v1.21.2";
        hash = "sha256-c6VuFyjt1smfHzEIJhjDJZ0nmna369PUvcVHXCRC00o=";
        targetNamespace = "cert-manager";
        createNamespace = true;
        values.crds.enabled = true;
      };
    };
  };

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
}
