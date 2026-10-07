# Publish a host service through k3s's Traefik, which owns :80/:443.
#
#   selfhost.expose.nextcloud = { domain = "cloud.matm.icu"; port = 8081; };
#
# Generates a selector-less Service + EndpointSlice pointing at this node, and
# an Ingress that cert-manager gives a Let's Encrypt certificate. The port
# stays closed in the host firewall: Traefik reaches it from the pod network
# over cni0, which is a trusted interface.
{
  config,
  lib,
  ...
}:
let
  cfg = config.selfhost.expose;
  namespace = "selfhost";

  manifests =
    name: svc:
    let
      labels."app.kubernetes.io/name" = name;
    in
    [
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          inherit name namespace labels;
        };
        spec.ports = [
          {
            name = "http";
            port = svc.port;
            targetPort = svc.port;
          }
        ];
      }
      {
        apiVersion = "discovery.k8s.io/v1";
        kind = "EndpointSlice";
        metadata = {
          name = "${name}-host";
          inherit namespace;
          labels = labels // {
            "kubernetes.io/service-name" = name;
            "endpointslice.kubernetes.io/managed-by" = "selfhost";
          };
        };
        addressType = "IPv4";
        ports = [
          {
            name = "http";
            port = svc.port;
            protocol = "TCP";
          }
        ];
        endpoints = [ { addresses = [ config.selfhost.exposeHostAddress ]; } ];
      }
      {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          inherit name namespace labels;
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt";
            "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure";
            "traefik.ingress.kubernetes.io/router.tls" = "true";
          };
        };
        spec = {
          ingressClassName = "traefik";
          tls = [
            {
              hosts = [ svc.domain ];
              secretName = "${name}-tls";
            }
          ];
          rules = [
            {
              host = svc.domain;
              http.paths = [
                {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    inherit name;
                    port.number = svc.port;
                  };
                }
              ];
            }
          ];
        };
      }
    ];
in
{
  options.selfhost.expose = lib.mkOption {
    default = { };
    description = "Host services to publish through Traefik with HTTPS.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          title = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Name on the dashboard. null hides it there.";
          };
          icon = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Glance icon, e.g. di:nextcloud (dashboard-icons) or si:github.";
          };
          domain = lib.mkOption {
            type = lib.types.str;
            description = "Public hostname. Needs a DNS record pointing at this box.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            description = "Plain-HTTP port the service listens on, on this host.";
          };
        };
      }
    );
  };

  options.selfhost.exposeHostAddress = lib.mkOption {
    type = lib.types.str;
    description = "Address Traefik uses to reach services on this host.";
  };

  config = lib.mkIf (cfg != { }) {
    services.k3s.manifests = {
      selfhost-namespace.content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = namespace;
      };
    }
    // lib.mapAttrs' (
      name: svc: lib.nameValuePair "expose-${name}" { content = manifests name svc; }
    ) cfg;
  };
}
