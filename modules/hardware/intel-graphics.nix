# Intel integrated graphics: video acceleration and the OpenCL compute stack.
#
# Replaces the intel-igc / intel-igc-libs / intel-opencl RPM trio from the
# Bluefin image. On NixOS the equivalent is intel-compute-runtime, which pulls
# in the Intel Graphics Compiler itself — the component the bluefin-xp comment
# noted had crashed on atomic_cmpxchg in variable-bound loops before being
# fixed upstream. Pinning is available here if it ever regresses again: override
# intel-compute-runtime, or take it from pkgs.unstable.
{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # VAAPI (iHD), Gen9 and newer
      intel-compute-runtime # OpenCL (NEO) — darktable, GIMP, rapid-photo-downloader
      vpl-gpu-rt # oneVPL runtime, Raptor Lake and newer
    ];
  };

  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  environment.systemPackages = with pkgs; [
    clinfo # verify OpenCL actually sees the GPU
    libva-utils # vainfo
    intel-gpu-tools # intel_gpu_top
  ];

  # Raptor Lake is served by i915, the default. The newer `xe` driver also binds
  # this generation and Bluefin had both modules loaded. If you want to try xe:
  #   boot.kernelParams = [ "i915.force_probe=!a7a0" "xe.force_probe=a7a0" ];
  # Leave it on i915 unless you have a specific reason — i915 is what darktable's
  # OpenCL path is tested against.
}
