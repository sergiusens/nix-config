# Captures Hyprland's own state at intervals after every resume, so a future
# black-screen-but-input-works incident (seen 2026-10-11) leaves a trace to
# look at afterward instead of needing someone to SSH in and catch it live.
#
# `hyprctl monitors` says whether Hyprland's IPC is even responding and what
# it thinks the display state is. The `ps` STAT column is the one that
# actually matters: R means running, S means merely sleeping, D means stuck
# inside an uninterruptible kernel wait -- most likely a DRM/GPU operation
# that is never returning. That distinction is invisible to every other log
# on this machine. Captured at 0/10/20/.../60s after resume since we do not
# know yet how long after waking this tends to happen.
#
# Logged via systemd-cat so it lands in the journal, which is flushed
# continuously and survives a later hard power-cycle -- `journalctl -b -1 -t
# resume-diag` after the fact replaces needing to catch it live.
{ pkgs, ... }:
let
  resumeDiagnostics = pkgs.writeShellApplication {
    name = "resume-diagnostics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.procps
      pkgs.util-linux
      pkgs.hyprland
      pkgs.systemd
    ];
    text = ''
      runtime_dir=/run/user/1000
      # shellcheck disable=SC2012 # signature dir names are plain hex, ls is fine
      sig=$(ls "$runtime_dir/hypr" 2>/dev/null | head -1)

      for t in 0 10 20 30 40 50 60; do
        if [ "$t" != "0" ]; then
          sleep 10
        fi
        {
          echo "=== resume-diag +''${t}s ==="
          runuser -u sergiusens -- env \
            XDG_RUNTIME_DIR="$runtime_dir" \
            HYPRLAND_INSTANCE_SIGNATURE="$sig" \
            hyprctl monitors 2>&1
          echo
          ps -o pid,stat,wchan:32,comm -C Hyprland
        } | systemd-cat -t resume-diag
      done
    '';
  };
in
{
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemd-run --no-block --unit=resume-diagnostics -- \
      ${resumeDiagnostics}/bin/resume-diagnostics
  '';
}
