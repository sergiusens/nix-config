# Which Hyprland desktop shell this host runs: DankMaterialShell (dank.nix)
# or Noctalia (noctalia.nix). Both are always available -- this is the one
# switch between them, so reverting is `desktop.shell = "dms";` (or back)
# plus a rebuild, never a git revert or re-adding deleted files.
#
# No default: each host (hosts/leto/default.nix, hosts/kynes/default.nix)
# must set this explicitly.
{ lib, ... }:
{
  options.desktop.shell = lib.mkOption {
    type = lib.types.enum [
      "dms"
      "noctalia"
    ];
    description = "Which Hyprland desktop shell this host runs.";
  };
}
