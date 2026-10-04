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

## Evaluates, but has never been built or booted

Both host configurations now evaluate to a derivation with no warnings beyond the
deliberate placeholder notice on `kynes`:

```
leto  → nixos-system-leto-26.05.20261002.774debe.drv
kynes → nixos-system-kynes-26.05.20261002.774debe.drv
```

`kynes` was also evaluated separately with `fleet.policy.enable = true`, on a throwaway
copy, since with the flag off the entire Falcon module, Kolide wiring and sops declarations
are never evaluated at all. That path is clean too.

So the module structure, option names and all six flake inputs are sound, and `leto`'s
evaluation confirms nixpkgs really does have the `services.v4l2-relayd` module that
`hardware.ipu6` depends on. It does **not** mean anything works: nothing has been built,
installed or booted. Evaluation cannot tell you whether the out-of-tree `ipu6-drivers`
compiles against the kernel, whether the camera captures a frame, or whether the sensor
reports in.

Nix cannot be installed on `leto` as it stands: Bluefin's `/` is read-only composefs, so
`/nix` cannot be created, and Nix needs that exact path because store paths are absolute
and baked into every binary. Homebrew does not help — there is no `nix` formula or cask,
only Nix *tooling* (`nixfmt`, `alejandra`, `statix`).

Evaluate in a container instead, which needs nothing installed:

```bash
podman run --rm --security-opt label=disable -v "$PWD":/work -w /work docker.io/nixos/nix \
  sh -lc 'export NIX_CONFIG="experimental-features = nix-command flakes";
          nix flake lock /work
          nix eval --raw /work#nixosConfigurations.leto.config.system.build.toplevel.drvPath'
```

Rootless podman maps container root to your own UID, so a `flake.lock` written this way is
owned by you. Use `-v "$PWD":/work:ro` plus `path:/work` for a read-only check, but note
that Nix then cannot write the lock file and will fail if one is missing.

If you want Nix on a bootc host permanently, the route is to bake `/nix` into the image
(you build `bluefin-xp`, so `RUN mkdir -p /nix` plus a systemd mount unit binding writable
storage over it) — but that is wasted effort for `leto`, which is being converted to NixOS
anyway. It only earns its keep on the five machines staying on bootc.

Fix what the evaluation surfaces before trusting anything below.

Fixed during the first evaluation, recorded so they are not reintroduced:

- **There is no `dell-xps-13-9320` in nixos-hardware.** The XPS 13 family stops at
  9315/9310/9350. Rather than borrow a neighbouring model's quirks, `flake.nix` composes
  `common-cpu-intel` + `common-pc-laptop` + `common-pc-laptop-ssd`.
- `pkgs.greetd.tuigreet` → `pkgs.tuigreet`
- `noto-fonts-emoji` → `noto-fonts-color-emoji`
- home-manager's `programs.git.userName`/`userEmail`/`extraConfig` → one freeform
  `programs.git.settings` attrset mirroring git's own config structure

## Installing

Step-by-step procedure: **[INSTALL.md](./INSTALL.md)**. Summary of the constraints:


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

## gthumb / Reflect

`../gthumb` is a personal fork of gThumb 4 on branch `reflect` — a NAS-backed proxy tree
with provenance, XMP-first metadata, card ingest and a narrow Immich integration. It now
carries its own `flake.nix` and `nix/package.nix`, and **builds cleanly**:

```bash
cd ../gthumb
nix build .#gthumb-reflect     # -> gthumb-reflect-4.0.rc
nix develop                    # full build environment
```

Dependency versions in nixpkgs 26.05 clear every floor meson asks for: gtk4 4.22.4
(needs ≥ 4.18.5), libadwaita 1.9.3 (≥ 1.8.0), exiv2 0.28.9 (≥ 0.28), libraw 0.22.1
(≥ 0.22), libportal 0.9.1 (≥ 0.9). The package installs two binaries — `gthumb` and the
`reflect` CLI — plus the desktop entry, icons, metainfo and GSettings schemas (nixpkgs
relocates those to `share/gsettings-schemas/…`, which `wrapGAppsHook4` puts on
`XDG_DATA_DIRS`).

`developer-mode` is **off**: upstream's `meson.options` says it "loads some resources from
the source tree", which a store-built package must never do. The cost is that the desktop
entry installs as `org.gnome.gthumb`, the same ID as upstream gthumb, so don't install
both. Turn `developerMode = true` on for the separate `-devel` entry and icon if you want
them side by side.

Worth noting what this replaces. The fork's own `AGENTS.md` describes building inside
`distrobox enter gthumb-dev` because Bluefin is immutable and lacks `-devel` packages, then
running on the host with

    GSETTINGS_SCHEMA_DIR="$PWD/build/data/schemas:/usr/share/glib-2.0/schemas" ./build/src/gthumb

because `meson devenv` narrows the schema path and every application gThumb launches
inherits it — Ansel dies on a missing `org.gtk.Settings.FileChooser`. On NixOS none of that
applies: `nix develop` is the build environment, and a packaged build has its schemas and
its children's schemas wired correctly.

It is **not** wired into `nixosConfigurations` yet, because the fork exists only on this
machine — its git remote is still upstream GNOME. `flake.nix` carries the commented input
and overlay line to uncomment once the branch is pushed somewhere.

## Adding a new machine

The point of the fleet layout. A new laptop is:

1. `cp -r hosts/leto hosts/<name>` — take a name from the reserved list in HOSTNAMES.md
   and keep the all-distinct-first-letters rule.
2. Adjust the hardware: check whether `nixos-hardware` has a module for the exact model
   (it did not for the XPS 13 Plus 9320), otherwise keep the generic laptop profiles.
   Drop `ipu6-camera.nix` unless the new machine has the same Intel MIPI camera, and swap
   `intel-graphics.nix` if it is AMD.
3. Add one line to `nixosConfigurations` in `flake.nix`.
4. Install over SSH from any booted installer:
   `nixos-anywhere --flake .#<name> --target-host root@<ip>` — disko partitions, NixOS
   installs, the config applies, in one command.

Everything shared comes free: the common baseline, Hyprland, the laptop profile, printing,
and the whole of home-manager. You can build the closure before the hardware arrives.

Four things are **not** automatic:

- **Secrets re-keying.** sops age keys are per-host, derived from the SSH host key. A new
  machine needs its key added to `.sops.yaml` and then
  `sops updatekeys secrets/policy.yaml`. This is the step that gets forgotten, and the
  symptom is a confusing activation failure.
- **Falcon and Kolide re-enrollment** on `kynes`-like hosts. The CID is unchanged but
  device identity is per-host: `gh auth login && falcon-sensor-install`, and Kolide
  enrolls afresh.
- **`system.stateVersion`** should be the release you install, not copied from leto.
- **Data.** Nix moves none of it. See below.

## Backups

Déjà Dup is installed but **not configured declaratively**, on purpose. The existing
repository is restic created with `--insecure-no-password`, i.e. unencrypted, so the plan
is to restore from it by hand after the reinstall and then set up a fresh encrypted
repository on a share named `leto`. Encryption cannot be retrofitted to a restic
repository.

`INSTALL.md` carries the restore procedure and the old settings for reference.

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

### leto's webcam needs the IPU6 stack

`leto` has **no USB webcam**. The front camera is an OmniVision OV01A10 MIPI sensor behind
the Raptor Lake IPU, so it is not a UVC device that works everywhere.

`modules/hardware/ipu6-camera.nix` enables nixpkgs' `hardware.ipu6` with
`platform = "ipu6ep"` (Alder Lake / Raptor Lake). That module does the real work: the
out-of-tree `ipu6-drivers` for the hardware ISP and i2c sensor drivers, the firmware, and
`v4l2-relayd` feeding Intel's `icamerasrc` pipeline through `v4l2loopback` to a fixed
`/dev/video50` labelled "Intel MIPI Camera". Applications therefore see an ordinary V4L2
camera, which is what makes browsers work. It also hides the ~30 raw Bayer nodes from
WirePlumber, which would otherwise show up as a pile of broken cameras.

This configuration is [reported working on exactly this
machine](https://gist.github.com/p-alik/6ed132ffad59de8fcbc4fb10b54d745e?permalink_comment_id=6136497)
as of May 2026, so it is on much firmer ground than most of this repo. Verify after first
boot:

```bash
v4l2-ctl --list-devices        # expect "Intel MIPI Camera" at /dev/video50
wpctl status                   # expect one Video/Source, not thirty
systemctl status v4l2-relayd-ipu6
```

One consequence worth knowing: `ipu6-drivers` is an **out-of-tree kernel module**, so it
must build against whichever kernel the host runs. That is why `modules/common` does not
pin `linuxPackages_latest` — an out-of-tree module that fails to build takes the whole
rebuild with it, and the usual symptom is "my camera broke after an update".

### There is no fingerprint reader

Checked on the running machine: `fprintd-list` reports "No devices available", and nothing
in `lsusb` resembles a fingerprint sensor — no Goodix (`27c6:*`), no Synaptics, no
Validity. `fprintd` and `libfprint` are installed and idle because there is nothing to
drive.

The one non-obvious USB device, `8086:0b63` "USB Bridge", is a red herring: its driver is
`ljca`, Intel's I2C/GPIO bridge, which is part of the *camera* plumbing — it carries the
OV01A10's I2C and GPIO lines.

On the XPS 13 Plus the reader sits in the power button and normally appears as a Goodix USB
device. Its total absence — not even an unbound device — means either this SKU shipped
without one or it is disabled in firmware; that cannot be distinguished from software, so
check the BIOS setup screen. **Do not wire up `pam_fprintd` expecting it to work.**

It does not work on Bluefin today either, so NixOS is not a regression here. If a `27c6:*`
device does appear after a firmware change, the next question is libfprint support — Dell's
newer Goodix match-on-chip sensors have patchy coverage.

### Suspend works, but only s2idle

Confirmed on the running machine: `/sys/power/mem_sleep` reports `[s2idle]` and nothing
else. Dell exposes no S3/deep state on the XPS 13 Plus, so suspend is Modern Standby.

It works today and will work the same under NixOS — it's kernel plus systemd, with nothing
Bluefin-specific involved. Suspend/resume is clean in the journal with devices suspending
in about 1.3 seconds.

The catch is that s2idle keeps RAM powered, so a closed lid over a weekend drains far more
than S3 would. The fix is `suspend-then-hibernate`, which is now worth wiring up because
the 64 GiB swapfile added for the OOM problem is comfortably larger than the 30 GiB
hibernation needs to write. It is commented out in `hosts/leto/default.nix` pending one
value that can only be read after the swapfile exists:

```bash
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
```

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
