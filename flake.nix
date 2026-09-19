{
  description = "Responsively App built from source for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    source = {
      url = "github:responsively-org/responsively-app/main";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , source
    ,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      perSystem = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          metadata = builtins.fromJSON (builtins.readFile "${source}/desktop-app/package.json");
          electronMajor = builtins.head (nixpkgs.lib.splitString "." metadata.devDependencies.electron);
          responsively = pkgs.callPackage ./packages/responsively.nix {
            inherit source;
            nodejs = pkgs.nodejs_24;
            electron = builtins.getAttr "electron_${electronMajor}" pkgs;
          };
        in
        {
          packages = {
            inherit responsively;
            default = responsively;
          };
          apps = {
            default = {
              type = "app";
              program = "${responsively}/bin/responsively";
              meta.description = "Responsively desktop browser";
            };
            mcp = {
              type = "app";
              program = "${responsively}/bin/responsively-mcp";
              meta.description = "Responsively stdio MCP bridge with on-demand app launch";
            };
          };
          checks = { inherit responsively; };
          formatter = pkgs.nixpkgs-fmt;
        }
      );
    in
    (builtins.mapAttrs (name: _: forAllSystems (system: perSystem.${system}.${name})) {
      packages = null;
      apps = null;
      checks = null;
      formatter = null;
    })
    // {
      nixosModules.default = import ./modules/nixos.nix { inherit self; };
      homeManagerModules.default = import ./modules/home-manager.nix { inherit self; };
    };
}
