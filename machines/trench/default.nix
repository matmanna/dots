{
  config,
  modulesPath,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./k3s.nix
    ./orchard.nix
    ./fetch.nix
    ./nextcloud.nix
    ./dawarich.nix
    ./vaultwarden.nix
    ./dashboard.nix
  ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  # disko adds /dev/sda to grub.devices because of the EF02 partition.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "trench";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.nameservers = [
    "1.1.1.1"
    "195.179.224.53"
    "209.126.15.53"
  ];

  # Static addressing copied from Contabo's cloud-init netplan.
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "00:50:56:68:01:42";
    address = [
      "157.173.116.9/20"
      "2a02:c207:2363:5109::1/64"
    ];
    routes = [
      { Gateway = "157.173.112.1"; }
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
    linkConfig.RequiredForOnline = "routable";
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
    ];
    # Pod and flannel traffic must reach the host (kubelet, servicelb, DNS).
    trustedInterfaces = [
      "cni0"
      "flannel.1"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users = {
    # Day-to-day account: herdr panes, agents, git. sudo for the rest.
    matmanna = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      # Password only matters at the Contabo VNC console; SSH is key-only.
      hashedPasswordFile = config.age.secrets.matmanna-password-hash.path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHK9lZa42dteyaGWWK4qfIyDV/CsJT8ZQjdORJCS7xSB git@matmanna.dev"
      ];
    };
    # Kept for deploy-rs and break-glass access until deploys move to matmanna.
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHK9lZa42dteyaGWWK4qfIyDV/CsJT8ZQjdORJCS7xSB git@matmanna.dev"
    ];
  };
  # Users and passwords come only from this config, re-applied every deploy.
  users.mutableUsers = false;
  age.secrets.matmanna-password-hash.file = ../../secrets/matmanna-password-hash.age;

  # Key-only SSH, so sudo doesn't prompt; the console password is for the
  # VNC console login alone.
  security.sudo.wheelNeedsPassword = false;

  # BuildKit and many pods watch lots of files.
  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 1048576;
  };

  selfhost.fail2ban.enable = true;
  selfhost.tailscale.enable = true;
  selfhost.zsh.enable = true;

  zramSwap.enable = true;

  time.timeZone = "UTC";

  environment.systemPackages = with pkgs; [
    git
    htop
    kubernetes-helm
    yq-go
    k9s
    chezmoi
    neovim
    # Saved-machine target for the local herdr client (`herdr machine add trench`).
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  system.stateVersion = "26.05";
}
