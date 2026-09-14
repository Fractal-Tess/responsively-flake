{ lib, package }:
{
  programs.responsively = {
    enable = lib.mkEnableOption "the Responsively desktop browser";

    package = lib.mkOption {
      type = lib.types.package;
      default = package;
      description = "Responsively package to install.";
    };
  };
}
