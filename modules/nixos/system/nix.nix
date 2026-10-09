{
  inputs,
  lib,
  config,
  ...
}:
let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Pin `nix run nixpkgs#…` and `<nixpkgs>` to this flake's inputs instead
      # of whatever the global registry or channels say today.
      flake-registry = "";
      # deploy-rs copies closures as the wheel user before sudo-activating.
      trusted-users = [
        "root"
        "@wheel"
      ];
      nix-path = config.nix.nixPath;
    };
    channel.enable = false;
    optimise.automatic = true;
    registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  # Garbage collection with a floor of recent generations, so a rollback
  # target always survives.
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
  };
}
