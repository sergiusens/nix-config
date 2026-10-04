# Secure Boot, via lanzaboote.
#
# Stock NixOS cannot do Secure Boot: nothing signs the kernel and initrd, so
# the firmware refuses them. Bluefin has Secure Boot enabled today
# (`bootctl status` reports "enabled (deployed)"), so migrating without this
# would quietly give up a security property the machine currently has.
#
# lanzaboote replaces systemd-boot's installer with one that builds signed
# Unified Kernel Images using keys you generate and enrol yourself.
#
# It also matters for the TPM. PCR 7 measures Secure Boot state and the
# enrolled keys, and that is the register a TPM LUKS policy normally binds to —
# so with Secure Boot off, a PCR 7 policy attests to very little.
# ORDER MATTERS: set Secure Boot up first, then enrol the TPM. Doing it the
# other way round changes PCR 7 afterwards and invalidates the policy, sending
# you to the recovery key.
{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  # lanzaboote installs the bootloader itself; the two cannot both own the ESP.
  # mkForce because modules/common enables systemd-boot for every host.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    # sbctl's current layout: keys/db/db.pem and keys/db/db.key live under here,
    # which is where the module's publicKeyFile and privateKeyFile default to.
    pkiBundle = "/var/lib/sbctl";
  };

  # sbctl generates and enrols the keys, and verifies what is signed.
  environment.systemPackages = [ pkgs.sbctl ];
}
