# HP printer and scanner support, including the proprietary HPLIP plugin.
#
# Confirmed wanted on leto — not an unexamined carry-over from bluefin-xp,
# unlike nextcloud-client, darktable and gimp, which were removed.
#
# This is the clearest win of the move to NixOS. bluefin-xp carried the plugin
# as a hand-assembled binary overlay committed into the image — prebuilt .so
# files under /usr/lib64/sane, firmware blobs, a pycache, and a
# hplip-plugin-state.service to sync state because /usr is read-only on bootc.
# All of it collapses into one attribute here: hplipWithPlugin fetches and wires
# the plugin itself.
{ pkgs, ... }:
let
  # The Canon profile, not the X-Rite one that was downloaded alongside it.
  # Both are prtr/RGB->Lab, but this one identifies what it is for:
  #   "CanonSelphy CP1500 - P KP36IP - F288v2 -23-03-04"
  # — printer, the KP-36IP paper and ink set, firmware revision and date. The
  # X-Rite file's description is merely its own filename, with no media named,
  # and a dye-sublimation profile is only meaningful for a specific paper.
  #
  # Installed under share/color/icc so colord picks it up by scanning
  # XDG_DATA_DIRS; nothing needs to copy it into /var/lib/colord.
  selphyIcc = pkgs.runCommand "canon-selphy-cp1500-icc" { } ''
    install -Dm444 ${../../assets/icc/Canon_Selphy_CP1500.icc} \
      "$out/share/color/icc/Canon_Selphy_CP1500.icc"
  '';

  # colord names CUPS devices cups-<queue>. Verified against this machine,
  # where the existing printer appears as
  # cups-HP_LaserJet_Professional_P_1102w.
  selphyQueue = "Canon_SELPHY_CP1500";
in
{
  services.printing = {
    enable = true;
    drivers = [
      pkgs.hplipWithPlugin
      # Selphy CP-series support lives in Gutenprint's canonselphy backend.
      # VERIFY the CP1500 specifically is in the version nixpkgs ships; if not,
      # the queue can still be driven by the generic CP-series PPD.
      pkgs.gutenprint
      pkgs.gutenprintBin
    ];
  };

  # Driverless discovery of network printers.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.hplipWithPlugin ];
  };

  # udev rules so the scanner is reachable without root; membership in the
  # "scanner" and "lp" groups is granted in modules/common.
  services.udev.packages = [ pkgs.hplipWithPlugin ];

  # ------------------------------------------------------- colour management --
  # colord is what CUPS consults for a printer's ICC profile, and what
  # darktable/Ansel consult for the display profile. Enabled explicitly rather
  # than relied upon as a side effect of something else pulling it in.
  services.colord.enable = true;

  # Binding a profile to a device is colord state, not configuration — there is
  # no NixOS option for it. This makes the binding reproducible instead:
  # idempotent, and a no-op until the queue actually exists.
  systemd.services.selphy-icc-bind = {
    description = "Bind the Canon SELPHY CP1500 ICC profile to its CUPS device";
    after = [
      "cups.service"
      "colord.service"
    ];
    wants = [
      "cups.service"
      "colord.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.colord
      pkgs.gnugrep
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      dev="cups-${selphyQueue}"

      if ! colormgr get-devices 2>/dev/null | grep -q "$dev"; then
        echo "colord has no device $dev yet — add the printer queue named" \
             "'${selphyQueue}' in CUPS, then: systemctl start selphy-icc-bind"
        exit 0
      fi

      prof=$(colormgr find-profile-by-filename \
        "${selphyIcc}/share/color/icc/Canon_Selphy_CP1500.icc" 2>/dev/null \
        | grep -oE 'icc-[0-9a-f]+' | head -1)

      if [ -z "$prof" ]; then
        echo "colord has not indexed the profile yet; it rescans periodically."
        exit 0
      fi

      # Both are idempotent; adding an already-bound profile is not an error
      # worth failing the unit over.
      colormgr device-add-profile "$dev" "$prof" || true
      colormgr device-make-profile-default "$dev" "$prof" || true
      echo "bound $prof to $dev"
    '';
  };

  environment.systemPackages = with pkgs; [
    simple-scan
    system-config-printer
    colord # colormgr, for inspecting and overriding the bindings by hand
    selphyIcc
  ];
}
