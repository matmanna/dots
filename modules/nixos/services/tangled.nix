# Tangled knot (git hosting on the AT Protocol), after taciturnaxolotl/dots'
# atelier.services.tangled. The HTTP side goes through Traefik with
# selfhost.expose; git over SSH needs public port 22, but only for the git
# user: everyone else may log in over Tailscale alone.
{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.selfhost.tangled;
in
{
  imports = [ inputs.tangled.nixosModules.knot ];

  options.selfhost.tangled = {
    enable = lib.mkEnableOption "a Tangled knot";

    owner = lib.mkOption {
      type = lib.types.str;
      description = "DID of the knot owner.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Public hostname of the knot (needs a DNS record).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5555;
    };

    internalPort = lib.mkOption {
      type = lib.types.port;
      default = 5444;
    };

    motd = lib.mkOption {
      type = lib.types.str;
      default = "Welcome to the knot!\n";
    };

    tailnetUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to SSH in, but only from the tailnet.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tangled.knot = {
      enable = true;
      server = {
        inherit (cfg) owner hostname;
        # 0.0.0.0 so Traefik (pod network) can reach it; the port stays
        # closed in the firewall.
        listenAddr = "0.0.0.0:${toString cfg.port}";
        internalListenAddr = "127.0.0.1:${toString cfg.internalPort}";
      };
      inherit (cfg) motd;
    };

    # Public SSH is for git only; the knot module opens port 22 for it.
    services.openssh.settings.AllowUsers = [
      config.services.tangled.knot.gitUser
    ]
    ++ map (u: "${u}@100.64.0.0/10") cfg.tailnetUsers;

    selfhost.expose.knot = {
      domain = cfg.hostname;
      port = cfg.port;
      title = "knot";
      icon = "si:git";
    };

    # Repositories and the knot's SQLite database.
    selfhost.backup.paths = [ config.services.tangled.knot.stateDir ];

    # Upstream knot leaks memory (see Kieran's notes): give Go a budget and a
    # hard backstop that restarts it instead of wedging the box.
    systemd.services.knot = {
      environment.GOMEMLIMIT = "1536MiB";
      serviceConfig = {
        MemoryMax = "2G";
        Restart = lib.mkForce "always";
      };
    };
  };
}
