# Blocks suspend outright while logind considers this machine docked.
#
# The dock's USB hub (VIA Labs 2109:8888, inside a Lenovo USB-C Mini Dock)
# does not reliably come back after s2idle resume -- the hub fails to
# re-link, which takes the keyboard, mouse and audio connected through it
# down with it. This happened at least twice. The symptom looks like a
# frozen machine: the kernel resumes cleanly, but nothing connected through
# the dock responds.
#
# `services.logind.settings.Login.HandleLidSwitchDocked = "ignore"` already
# stops the LID from suspending while docked, but that is the only trigger
# logind lets you gate on docked state. The power key, the power menu, DMS's
# own idle timer and a plain `systemctl suspend` are not covered -- any of
# them can still suspend a docked machine, and then hit the same hub bug on
# the way back up.
#
# This holds a blocking sleep inhibitor for as long as `busctl` reports the
# machine docked, which makes logind refuse every one of those triggers
# uniformly, without touching any of them individually.
{ pkgs, ... }:
let
  dockSleepGuard = pkgs.writeShellApplication {
    name = "dock-sleep-guard";
    runtimeInputs = [
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      inhibit_pid=""

      is_docked() {
        busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
          org.freedesktop.login1.Manager Docked 2>/dev/null | grep -q "^b true$"
      }

      cleanup() {
        if [ -n "$inhibit_pid" ]; then
          kill "$inhibit_pid" 2>/dev/null || true
        fi
      }
      trap cleanup EXIT

      while true; do
        if is_docked && [ -z "$inhibit_pid" ]; then
          systemd-inhibit --what=sleep --mode=block \
            --who="dock-sleep-guard" \
            --why="docked: the dock's USB hub does not reliably resume from suspend" \
            sleep infinity &
          inhibit_pid=$!
        elif ! is_docked && [ -n "$inhibit_pid" ]; then
          kill "$inhibit_pid" 2>/dev/null || true
          wait "$inhibit_pid" 2>/dev/null || true
          inhibit_pid=""
        fi
        sleep 5
      done
    '';
  };
in
{
  systemd.services.dock-sleep-guard = {
    description = "Block suspend while docked (dock USB hub does not survive resume)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-logind.service" ];
    serviceConfig = {
      ExecStart = "${dockSleepGuard}/bin/dock-sleep-guard";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
