{ self }:
{ config
, lib
, pkgs
, ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  package = self.packages.${system}.responsively;
  cfg = config.programs.responsively;
in
{
  options = import ./options.nix { inherit lib package; };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
