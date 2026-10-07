# Intel integrated graphics: video acceleration and the OpenCL compute stack.
#
# The heavy lifting is done by nixos-hardware's common-gpu-intel profile, pulled
# in via common-cpu-intel in flake.nix. It handles hardware.graphics.extraPackages
# (including the 32-bit variants), loads the GPU module in initrd, and selects the
# right runtime generation. This file only expresses the choices for THIS hardware.
#
# Together this replaces the intel-igc / intel-igc-libs / intel-opencl RPM trio
# from the Bluefin image: the NixOS equivalent is intel-compute-runtime, which
# brings the Intel Graphics Compiler with it — the component whose
# atomic_cmpxchg bug in variable-bound loops the bluefin-xp comment recorded,
# since fixed upstream. If it ever regresses, pin by overriding
# intel-compute-runtime or take it from pkgs.unstable.
{ lib, pkgs, ... }:
{
  hardware.intelgpu = {
    # i915 is the default and what darktable's OpenCL path is tested against.
    # The xe driver also binds Raptor Lake (Bluefin had both modules loaded) and
    # the profile asserts kernel >= 6.8 for it, but there is no reason to switch.
    #
    # mkDefault because this is leto's choice, not a fleet rule. kynes is Lunar
    # Lake (Arc 140V, Xe2), which i915 does not drive at all. nixos-hardware's
    # lunar-lake GPU profile sets "xe" and must win there.
    driver = lib.mkDefault "i915";

    # Raptor Lake is Gen12+ and Lunar Lake is Xe2, so the default (non-legacy)
    # intel-compute-runtime is correct for both. Stated explicitly because getting this wrong gives you an
    # OpenCL stack that loads but never sees the GPU.
    computeRuntime = "default";

    # oneVPL, correct for Gen12 and newer.
    mediaRuntime = "vpl-gpu-rt";

    # The profile defaults to null, which installs BOTH intel-media-driver (iHD)
    # and the legacy intel-vaapi-driver (i965). i965 does nothing on Gen12, so
    # pick iHD alone and keep the closure smaller.
    vaapiDriver = "intel-media-driver";
  };

  # Not set by the profile, and applications need it to pick iHD.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  environment.systemPackages = with pkgs; [
    clinfo # verify OpenCL actually sees the GPU
    libva-utils # vainfo
    intel-gpu-tools # intel_gpu_top
  ];
}
