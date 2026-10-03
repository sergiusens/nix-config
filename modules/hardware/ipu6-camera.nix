# Intel IPU6 MIPI camera (leto: Raptor Lake IPU + OmniVision OV01A10).
#
# This machine has NO USB webcam. The front camera is a MIPI CSI-2 sensor behind
# Intel's Image Processing Unit, which is why it is not simply a UVC device that
# works everywhere. Confirmed on the running Bluefin system:
#   00:05.0 Multimedia controller: Intel Corporation Raptor Lake IPU [8086:a75d]
#   Kernel driver in use: intel-ipu6
#   sensor module: ov01a10 (ACPI OVTI01A0), glue: intel_skl_int3472_*
#   firmware: intel/ipu/ipu6ep_fw.bin  -> platform is "ipu6ep"
#
# The pipeline is:
#   sensor -> IPU6 ISYS (raw Bayer capture, IN-TREE since kernel 6.10)
#          -> libcamera Simple pipeline -> SoftISP (debayer; GPU-accelerated
#             since libcamera 0.7) -> PipeWire -> applications
#
# Deliberately NOT setting hardware.ipu6.enable. That option brings in Intel's
# proprietary ipu6-camera-hal / icamerasrc stack together with the out-of-tree
# ipu6-drivers, which was the only route before 6.10 but now conflicts with the
# in-tree modules. For the OV01A10 in particular the libcamera path is the one
# that works; mixing the two is a known way to end up with neither.
#
# ####################### VERIFY THIS ON FIRST BOOT #######################
# This is the highest-risk item on leto and it is NOT confirmed working under
# NixOS. The kernel side should be automatic, but the libcamera/PipeWire
# plumbing below is the part most likely to need adjustment. Check with:
#   cam -l                      # libcamera should list the OV01A10
#   wpctl status                # PipeWire should show a Video/Source
# If the camera matters before this is solved, any cheap USB UVC webcam works
# immediately and bypasses all of it.
# #########################################################################
{ pkgs, ... }:
{
  # Loaded automatically by ACPI matching on this hardware; listed explicitly so
  # a failure to bind is visible rather than silent.
  boot.kernelModules = [
    "intel_ipu6"
    "intel_ipu6_isys"
    "ipu_bridge"
    "ov01a10"
  ];

  # Firmware (intel/ipu/ipu6ep_fw.bin) ships in linux-firmware; pulled in by
  # hardware.enableRedistributableFirmware, set in hosts/leto/default.nix.

  environment.systemPackages = with pkgs; [
    libcamera # provides `cam` for diagnosis, and the SoftISP itself
    v4l-utils # v4l2-ctl --list-devices
  ];

  # Applications reach a libcamera device through PipeWire, not /dev/video*
  # directly — the ISYS nodes expose raw Bayer that nothing but libcamera
  # understands. WirePlumber 0.5 needs its libcamera monitor switched on
  # explicitly; without this the camera exists but no application sees it.
  #
  # VERIFY: the profile syntax below is for WirePlumber 0.5. Check it against
  # the pinned nixpkgs, and that the pipewire build has its libcamera SPA
  # plugin enabled.
  services.pipewire.wireplumber.extraConfig."10-libcamera" = {
    "wireplumber.profiles".main."monitor.libcamera" = "required";
  };
}
