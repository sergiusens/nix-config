# Intel IPU6 MIPI camera (leto: Raptor Lake IPU + OmniVision OV01A10).
#
# This machine has NO USB webcam. The front camera is a MIPI CSI-2 sensor behind
# Intel's Image Processing Unit, which is why it is not simply a UVC device.
# Confirmed on the running Bluefin system:
#   00:05.0 Multimedia controller: Intel Corporation Raptor Lake IPU [8086:a75d]
#   Kernel driver in use: intel-ipu6
#   sensor module: ov01a10 (ACPI OVTI01A0), glue: intel_skl_int3472_*
#   firmware: intel/ipu/ipu6ep_fw.bin  -> platform is "ipu6ep"
#
# nixpkgs' hardware.ipu6 module does all the real work, and does it well:
#
#   - pulls boot.extraModulePackages = [ ipu6-drivers ]. ISYS (raw capture) has
#     been in-tree since 6.10, but the out-of-tree package is still needed for
#     intel-ipu6-psys (the hardware ISP) and some i2c sensor drivers, so the two
#     are complementary rather than conflicting.
#   - firmware: ipu6-camera-bins and ivsc-firmware.
#   - runs v4l2-relayd, feeding Intel's proprietary icamerasrc GStreamer
#     pipeline through v4l2loopback to a FIXED /dev/video50 labelled
#     "Intel MIPI Camera". Applications therefore see an ordinary V4L2 camera,
#     which is what makes browsers and Electron apps work. The device number is
#     pinned because application camera permission grants are keyed to the
#     PipeWire node name, which derives from the sysfs path.
#   - hides the raw IPU6 nodes from WirePlumber (they carry raw Bayer that
#     nothing but libcamera understands, and would otherwise appear as a pile of
#     broken cameras) and restricts them to root via udev with TAG-="uaccess".
#
# This uses the IPU's hardware ISP via Intel's camera HAL, so image quality is
# better than the libcamera SoftISP route, which debayers on CPU/GPU instead.
#
# Reported working on exactly this machine with exactly this configuration:
# https://gist.github.com/p-alik/6ed132ffad59de8fcbc4fb10b54d745e?permalink_comment_id=6136497
{ pkgs, ... }:
{
  hardware.ipu6 = {
    enable = true;
    # ipu6 = Tiger Lake, ipu6ep = Alder Lake / Raptor Lake, ipu6epmtl = Meteor Lake.
    platform = "ipu6ep";
    # videoDeviceNumber defaults to 50, clear of the IPU6 raw node range (3-34).
  };

  environment.systemPackages = with pkgs; [
    libcamera # `cam -l` for diagnosis
    v4l-utils # v4l2-ctl --list-devices
  ];

  # Verify after the first boot:
  #   v4l2-ctl --list-devices        # expect "Intel MIPI Camera" at /dev/video50
  #   wpctl status                   # expect one Video/Source, not 30-odd
  #   systemctl status v4l2-relayd-ipu6
  #
  # NOTE: ipu6-drivers is an out-of-tree kernel module, so it must build against
  # whichever kernel this host runs. That is why modules/common no longer pins
  # linuxPackages_latest — see the comment there.
}
