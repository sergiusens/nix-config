# home-manager wiring, shared by every host.
{ inputs, hostName, ... }:
{
  home-manager = {
    # Use the system's pkgs (with our overlays) instead of a second instance.
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs hostName; };

    # Keeps a rebuild from failing when home-manager wants to write a file that
    # already exists; the displaced original is saved with this suffix.
    backupFileExtension = "hm-bak";

    users.sergiusens = import ../../home/sergiusens;
  };
}
