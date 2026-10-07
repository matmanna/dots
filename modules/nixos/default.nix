{
  imports = [
    ./system/nix.nix
    ./system/fail2ban.nix
    ./system/tailscale.nix
    ./system/zsh.nix
    ./services/backup.nix
    ./services/expose.nix
    ./services/dashboard.nix
  ];
}
