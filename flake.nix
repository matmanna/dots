{
  description = "matmanna's machines: trench (NixOS + k3s + Orchard on Contabo)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:herdrdev/herdr/v0.9.3";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nixarr = {
      url = "github:nix-media-server/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stable is too old for deploy-rs.
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      agenix,
      deploy-rs,
      ...
    }@inputs:
    let
      forSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
    in
    {
      nixosConfigurations.trench = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          inputs.nixarr.nixosModules.default
          ./modules/nixos
          ./machines/trench
        ];
      };

      # `nix run .#deploy` (or `deploy .#trench` in the dev shell). Magic
      # rollback reverts the switch if the box stops answering over SSH, which
      # on a VPS with hand-written static networking beats the VNC console.
      deploy.nodes.trench = {
        # Over Tailscale; public SSH is closed.
        hostname = "trench.tail4a3e06.ts.net";
        # Activates as root through passwordless sudo.
        sshUser = "matmanna";
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.trench;
        };
      };

      checks = builtins.mapAttrs (_: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      devShells = forSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            # Hooks live in the repo; point git at them in every clone.
            shellHook = "git config core.hooksPath .githooks";
            packages = [
              deploy-rs.packages.${system}.default
              agenix.packages.${system}.default
              pkgs.nixos-anywhere
              pkgs.nixfmt
              pkgs.gitleaks
            ];
          };
        }
      );

      apps = forSystems (system: {
        deploy = {
          type = "app";
          program = "${deploy-rs.packages.${system}.default}/bin/deploy";
        };
      });
    };
}
