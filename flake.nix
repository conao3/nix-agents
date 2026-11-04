{
  description = "home-manager module for running coding agents as multiple instances";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
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
        { pkgs, system, ... }:
        let
          unfreePkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          home = {
            home = {
              username = "example";
              homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/example" else "/home/example";
              stateVersion = "25.11";
            };
          };
          evalExample =
            name: example:
            let
              config = inputs.home-manager.lib.homeManagerConfiguration {
                pkgs = unfreePkgs;
                modules = [
                  inputs.self.homeManagerModules.default
                  home
                  example
                ];
              };
            in
            pkgs.writeText "eval-${name}" (
              builtins.unsafeDiscardStringContext config.activationPackage.drvPath
            );
        in
        {
          treefmt.programs.nixfmt.enable = true;

          devShells.default = pkgs.mkShell {
            packages = [ pkgs.gnumake ];
          };

          checks.eval-minimal = evalExample "minimal" ./examples/minimal.nix;
          checks.eval-practical = evalExample "practical" ./examples/practical.nix;
          checks.eval-supported-agents = evalExample "supported-agents" ./examples/supported-agents.nix;
          checks.eval-extras = evalExample "extras" ./examples/extras.nix;
          checks.readme-examples =
            let
              readme = builtins.readFile ./README.md;
              missing = builtins.filter (f: !(pkgs.lib.hasInfix (builtins.readFile f) readme)) [
                ./examples/minimal.nix
                ./examples/practical.nix
                ./examples/supported-agents.nix
                ./examples/extras.nix
              ];
            in
            if missing == [ ] then
              pkgs.writeText "readme-examples" "ok"
            else
              throw "README.md does not contain ${toString missing}";

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
