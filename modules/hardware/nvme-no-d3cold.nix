# Keeps the NVMe SSD behind Intel VMD out of D3cold (fully powered off)
# during suspend.
#
# Root cause and fix lifted from a community repo for an unrelated laptop
# (Asus Vivobook 16X K3605) that hit the exact same VMD device ID as this
# machine: https://github.com/nikodmus/asus-k3605-suspend-fix
#
# After multiple hard-freeze-on-resume incidents here with zero kernel log
# output (not even the NMI watchdog -- consistent with a device that is
# completely powered off and never responds to anything, including its own
# driver's resume call, rather than a software hang), confirmed this
# machine's NVMe (behind `Intel RST VMD Managed Controller [8086:a77f]`,
# `lspci -nn`) and its VMD-bridged upstream PCIe port both have
# d3cold_allowed=1 right now -- the exact condition that repo's writeup
# identifies as the cause on the same VMD device ID. Not proven to be THE
# fix for this specific machine yet, but the device ID match is exact and
# the failure mode matches precisely, so this is worth testing before
# assuming it is not it.
{ ... }:
{
  services.udev.extraRules = ''
    # NVMe SSD behind Intel VMD, and its upstream PCIe port.
    ACTION=="add", SUBSYSTEM=="pci", ATTR{class}=="0x010802", \
      ATTR{d3cold_allowed}="0", RUN+="/bin/sh -c 'echo 0 > /sys%p/../d3cold_allowed'"
  '';
}
