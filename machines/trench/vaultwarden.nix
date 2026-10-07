# Vaultwarden at vault.matm.icu. Rocket listens on :8222 (closed in the
# firewall, websockets included); Traefik terminates TLS via selfhost.expose.
#
# Signups are closed. Create accounts from https://vault.matm.icu/admin
# (token: secrets/vaultwarden/admin-token.age) with "Invite user"; without
# SMTP an invited address can register straight away.
{ config, ... }:
let
  domain = "vault.matm.icu";
  port = 8222;
in
{
  age.secrets."vaultwarden/env".file = ../../secrets/vaultwarden/env.age;
  age.secrets."vaultwarden/admin-token".file = ../../secrets/vaultwarden/admin-token.age;

  services.vaultwarden = {
    enable = true;
    inherit domain;
    # Nightly consistent SQLite copy, picked up by selfhost.backup.
    backupDir = "/var/backup/vaultwarden";
    environmentFile = [ config.age.secrets."vaultwarden/env".path ];
    config = {
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = port;
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = true;
      SHOW_PASSWORD_HINT = false;
      # Traefik sets X-Real-Ip; log real client addresses (fail2ban-friendly).
      IP_HEADER = "X-Real-IP";
    };
  };

  selfhost.expose.vaultwarden = {
    inherit domain port;
    title = "vaultwarden";
    icon = "di:vaultwarden";
  };
}
