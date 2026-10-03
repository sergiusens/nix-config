# nix-config

NixOS configurations for the Atreides fleet. See [HOSTNAMES.md](./HOSTNAMES.md) for the
host roster and [AGENTS.md](./AGENTS.md) for repository conventions.

## Hosts

| Host | Machine | Status |
| --- | --- | --- |
| `leto` | Dell XPS 13 Plus 9320 — photo workstation | config written, never built |
| `kynes` | work laptop | config written, **hardware unknown** |

The other five machines in the roster stay on bootc/Universal Blue for now, built by
`../bluefin-xp`.

## Layout

```
flake.nix                    inputs, the mkHost helper, nixosConfigurations
hosts/<host>/                per-machine config and disk layout
modules/common/              baseline shared by every host
modules/desktop/hyprland.nix compositor, greeter, portals
modules/hardware/            Intel graphics, HP printing/scanning
modules/profiles/laptop.nix  power, lid, bluetooth, firmware
modules/work/                CrowdStrike and Kolide stubs (disabled, untested)
home/sergiusens/             home-manager: ghostty, waybar, Hyprland keybinds
```

## Nothing here has been built

**No part of this has been evaluated, let alone booted.** Nix is not installed on `leto`,
so not one line has been through `nix eval`. Expect option-name drift against the pinned
nixpkgs — NixOS renames options between releases and several used here are recent
(`hardware.graphics`, `services.logind.settings`, `nerd-fonts.*`).

First thing to do, from any machine with Nix:

```bash
nix flake check
nix eval .#nixosConfigurations.leto.config.system.build.toplevel.drvPath
```

Fix what that surfaces before trusting anything below.

Two specific things to verify:

- **`nixos-hardware.nixosModules.dell-xps-13-9320`** — the attribute name is assumed, not
  confirmed. Check `nixos-hardware`'s flake outputs; it may be spelled differently or not
  exist for the 9320.
- **`home-manager/release-26.05`** — assumed to track the nixpkgs release. Adjust if that
  branch doesn't exist yet.

## Installing

`hosts/leto/disko.nix` describes the disk layout declaratively. It is inert during
`nixos-rebuild`; only an explicit `disko` invocation touches a disk, and that invocation
**destroys everything on `/dev/nvme0n1`**.

`leto` currently holds **506 GB of data** on its existing LUKS+btrfs volume, and the
layout here is not a drop-in replacement for the ostree one — the ESP grows from 600 MB to
2 GB and the separate `/boot` goes away, so the partition table is rewritten. Back up
`/var/home` somewhere off the machine and verify the backup before you start.

Note also that `leto` is the machine this repository is edited from, so it cannot install
itself. You need either a NixOS USB installer or [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
driven from another machine.

Home directories move from `/var/home/sergiusens` (ostree) to `/home/sergiusens`
(NixOS). Anything with that path baked in needs updating.

## Deploying

Once a host runs NixOS, from this directory:

```bash
# local
sudo nixos-rebuild switch --flake .#leto

# remote
nixos-rebuild switch --flake .#kynes --target-host root@kynes.atreides --fast
```

`nixos-rebuild --target-host` has no rollback protection. For anything you can't easily
walk over to, prefer [deploy-rs](https://github.com/serokell/deploy-rs), whose magic
rollback reverts a config that breaks its own connectivity after 30 seconds.

## Caveats worth reading before you commit to this

### Colour management, for a photo machine

This is the one that should give you pause. GNOME has mature display colour management;
Wayland's colour-management protocol is much newer, and support across compositors and
applications is uneven. Hyprland implements it in recent versions, but whether **darktable
and GIMP honour an ICC display profile** end-to-end under Hyprland is something you should
test before migrating photo work, not after.

If calibrated colour matters to your workflow, test it on a spare install first. It would
be a poor trade to get a declarative system and lose colour accuracy on the machine whose
entire job is photographs.

### The work laptop's compliance agents

No longer stubs. `modules/work/policy.nix` wires up both agents, gated behind
`fleet.policy.enable`, which is **off** until `secrets/policy.yaml` is a real
sops-encrypted file.

**Kolide** is packaged properly upstream by Kolide themselves
([`kolide/nix-agent`](https://github.com/kolide/nix-agent)), so it is a flake input and a
module import rather than anything hand-rolled. One non-obvious override is carried over:
`TimeoutStopSec = 180`, because the 90-second default is sometimes too short for osquery
to flush its event store on a long-running workstation, and the SIGKILL leaves writes
half-flushed. The unit's `PATH` is also composed explicitly — the launcher spawns its tray
process with a fresh environment and copies only `PATH`, so browsers named in `.desktop`
entries must be reachable through it.

**Falcon** cannot be packaged declaratively and is not attempted as a derivation. The
sensor binaries are bootstrapped imperatively to `/opt/CrowdStrike` and patchelf'd onto the
Nix glibc interpreter:

```bash
gh auth login          # the script lifts the token from your gh session
falcon-sensor-install  # self-elevates; --version, --force, --direct available
falcon-sensor-check    # health report
```

The systemd unit carries `ConditionPathExists=/opt/CrowdStrike/falcond`, so it stays inert
rather than failing until that has run.

The module and its two scripts are **vendored verbatim** from a colleague's configuration
under the Blue Oak Model License — see [modules/work/ATTRIBUTION.md](./modules/work/ATTRIBUTION.md)
for provenance, the pinned commit, and checksums. They encode a lot of hard-won detail that
is not obvious and would have taken a long time to rediscover:

- the kernel-module backend does not work on NixOS, so `--backend=bpf` is forced
- sensor 7.38+ arms tamper protection while running: kill signals are blocked at kernel
  level *even from systemd as PID 1*, and `/opt/CrowdStrike` is write-protected even
  against root. Hence `restartIfChanged = false`, and updates that stage to
  `/opt/CrowdStrike.staged` for a boot-time oneshot to apply
- without that, a unit restart leaves the old armed sensor running detached from systemd
  while the new one respawns to exit status 85 until the respawn cap trips — a 461-attempt
  restart loop was observed in the wild
- logrotate uses `copytruncate`, because the vendor's `pkill -HUP` pattern is blocked by
  tamper protection, and restarting a security sensor to rotate logs would create blind
  windows in EDR coverage
- `nix-ld` with `libnl` added, plus `NIX_LD`/`NIX_LD_LIBRARY_PATH` in the unit, so
  cloud-staged sensor binaries CrowdStrike pushes down — which reference
  `/lib64/ld-linux-x86-64.so.2` and are not patched by us — can still exec

Because it is vendored rather than consumed as a flake input, upstream fixes do not arrive
automatically. **Check the upstream commit before debugging anything in there.**

Still worth confirming your employer sanctions a NixOS endpoint before relying on this.
It is unofficial and unsupported by CrowdStrike.

### Swap and OOM

`leto`'s photo applications were dying under memory pressure. Investigation found no
kernel OOM kills at all — the real situation was 16 GiB of zram (which lives *inside* the
30 GiB of RAM and so adds no capacity), holding 4 KB, with `vm.swappiness=10` suppressing
what little swap existed, plus `systemd-oomd` active and killing on pressure.

The fix is three-part: a real 64 GiB NVMe swapfile on its own btrfs subvolume
(`hosts/leto/disko.nix`), zram reduced to 25% with swappiness raised to 100
(`modules/common`), and `systemd.oomd.enableUserSlices = false` so the pressure killer
leaves desktop applications alone (`hosts/leto`).

Since no kernel OOM was ever logged, it's worth confirming the crashes really are memory
exhaustion and not the applications failing an allocation for another reason. If they
recur with 64 GiB of swap available, look elsewhere.

Hibernation is not configured — it needs the swapfile's physical offset, which only exists
once the file does. Commands are in `hosts/leto/default.nix`.

## Next steps

1. `nix flake check` somewhere with Nix; fix the option drift.
2. Generate `hosts/kynes/hardware-configuration.nix` on the real machine.
3. Test the colour-management path before migrating photo work.
4. Set up `sops-nix`: put real age public keys in `.sops.yaml`, then
   `sops secrets/policy.yaml` with `kolide`, `falcon-cid` and `falcon-repo`. The file
   currently in the repo is an unencrypted placeholder so the flake evaluates — replace it
   before setting `fleet.policy.enable = true`.
5. Add SSH public keys to `users.users.sergiusens.openssh.authorizedKeys.keys`; it is
   deliberately empty.
6. Pick a wallpaper for `hyprpaper`, currently unset.
