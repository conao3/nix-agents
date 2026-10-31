{
  description = "home-manager module for running coding agents as multiple instances";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      imports = [ inputs.treefmt-nix.flakeModule ];

      flake.homeManagerModules = rec {
        agents = ./default.nix;
        default = agents;
      };

      perSystem =
        { pkgs, ... }:
        {
          treefmt.programs.nixfmt.enable = true;

          devShells.default = pkgs.mkShell {
            packages = [ pkgs.gnumake ];
          };

          checks.example =
            (inputs.home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                inputs.self.homeManagerModules.default
                ./examples/basic.nix
              ];
            }).activationPackage;
        };
    };
}
