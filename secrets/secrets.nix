# agenix recipients. Encrypt with `agenix -e <name>.age` from this directory.
# Every secret is readable by the user key (to edit) and by each host that
# needs it (to decrypt at boot with its SSH host key).
let
  matmanna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHK9lZa42dteyaGWWK4qfIyDV/CsJT8ZQjdORJCS7xSB git@matmanna.dev";
  trench = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIImusIU+JibhiZODWYbtds5HXuGlaFkqV0tGalAwkJ1J";

  onTrench = [
    matmanna
    trench
  ];
in
{
  # KEY=value lines for Orchard: JWT_SECRET, SECRETS_ENCRYPTION_KEY,
  # SSO_ENCRYPTION_KEY, MCP_SERVICE_TOKEN, REGISTRY_PASSWORD.
  "orchard.age".publicKeys = onTrench;

  # Login password for "matmanna" on trench, only for the Contabo VNC console
  # (SSH stays key-only): hash is what the system reads, password is for you.
  "matmanna-password-hash.age".publicKeys = onTrench;
  "matmanna-password.age".publicKeys = onTrench;

  # Nextcloud admin account password (user "admin").
  "nextcloud-admin.age".publicKeys = onTrench;

  # Dawarich admin account password (vps@matmanna.dev).
  "dawarich-admin.age".publicKeys = onTrench;

  # Immich admin account password (vps@matmanna.dev).
  "immich-admin.age".publicKeys = onTrench;

  # Vaultwarden: env holds ADMIN_TOKEN (argon2 hash) for the server,
  # admin-token is the plaintext token you type into /admin.
  "vaultwarden/env.age".publicKeys = onTrench;
  "vaultwarden/admin-token.age".publicKeys = onTrench;

  # restic: env holds the storage credentials (e.g. AWS_ACCESS_KEY_ID /
  # AWS_SECRET_ACCESS_KEY for R2 or B2), repo the repository URL, password
  # the repository encryption password.
  "restic/env.age".publicKeys = onTrench;
  "restic/repo.age".publicKeys = onTrench;
  "restic/password.age".publicKeys = onTrench;
}
