# Installing

For `leto`. `kynes` needs a real `hardware-configuration.nix` first — see README.md.

## Try it in a VM before touching the laptop

This costs nothing and answers the questions that matter: does the greeter come up, does
Hyprland start, do the keybinds work, is the font legible.

```bash
nix build .#nixosConfigurations.leto.config.system.build.vm
./result/bin/run-leto-vm
```

Log in as `sergiusens` / `vm`. Those credentials come from `virtualisation.vmVariant` in
`hosts/leto/default.nix` and exist **only** in the VM — the installed system still has no
password until you set one.

The VM substitutes its own disk, so `disko.nix` is ignored and nothing on the host is
touched; `qemu-vm` neutralises the LUKS device and swapfile with `mkVMOverride`, so it
will not stall in initrd. The VM variant also forces off the IPU6 camera stack and
printing, neither of which exists in a VM.

It cannot tell you anything about the camera, the GPU or suspend — those need real
hardware.

### Running it from Bluefin, which has no Nix

`/nix` cannot exist on Bluefin's read-only root, so the build happens in a container
(see README.md) and the VM's QEMU, kernel and initrd all live inside that container's
store volume. The host cannot execute the runner directly. Run it in the container and
take the display out over VNC:

```bash
mkdir -p ~/.cache/leto-vm
VM=$(podman run --rm --security-opt label=disable -v nix-store:/nix -v "$PWD":/work -w /work \
      docker.io/nixos/nix sh -lc 'export NIX_CONFIG="experimental-features = nix-command flakes";
        nix build --no-link --print-out-paths /work#nixosConfigurations.leto.config.system.build.vm')

podman run --rm --name leto-vm --device /dev/kvm --security-opt label=disable \
  -p 5900:5900 -v nix-store:/nix -v ~/.cache/leto-vm:/vm -w /vm \
  docker.io/nixos/nix \
  sh -lc "QEMU_OPTS='-display vnc=0.0.0.0:0 -vga virtio' $VM/bin/run-leto-vm"
```

Then from the host:

```bash
remote-viewer vnc://127.0.0.1:5900     # virt-viewer is already installed on Bluefin
podman stop leto-vm                    # when done
```

**Use `127.0.0.1`, not `localhost`.** `localhost` resolves to `::1` first, and podman's
rootless pasta networking forwards only IPv4, so the v6 attempt is reset and the client
reports "Unable to read from server" even though QEMU is listening perfectly well. Check
the server directly if in doubt — a healthy one answers with its handshake banner:

```bash
python3 -c 'import socket;s=socket.create_connection(("127.0.0.1",5900),4);print(s.recv(32))'
# -> b'RFB 003.008\n'
```

`/dev/kvm` is world-writable on Bluefin, so no group membership is needed. The qcow2 lands
in `~/.cache/leto-vm`; delete it to start from a clean disk.

### What to look for

- The greeter appears, legibly, at a sensible size, and matches the live DMS theme.
- **Hyprland starts after login.** dank-greeter launches `compositor.name` directly, so
  there is no session dropdown to check.
- Super+Return opens Ghostty; Super+Shift+Return opens foot; Super+D opens fuzzel.
- waybar is present, the keyboard is `latam`, and the theme is dark.

## Before you start

- **`leto` cannot install itself.** It is the machine you are reading this on, and the
  install destroys its disk. You need a NixOS installer USB, or `nixos-anywhere` driven
  from another machine.
- **Back up and verify the backup.** The disk gets repartitioned: the ESP grows from
  600 MB to 2 GB and the separate `/boot` disappears, so the partition table is rewritten.
  Déjà Dup covers `$HOME`; it does **not** cover anything outside it.
- **Get the config onto the target.** This repo has no remote. Copy it to the USB stick,
  push it somewhere private and clone it, or `scp` it from another machine.
- **Home directories move** from `/var/home/sergiusens` to `/home/sergiusens`. Anything
  with that path baked in needs updating.

## Install

1. Boot the NixOS minimal ISO, get networking up (`nmtui` for wifi).

2. Enable flakes for the installer shell:

   ```bash
   export NIX_CONFIG="experimental-features = nix-command flakes"
   ```

3. **Sanity-check the hardware config against the real machine** before committing.
   `hosts/leto/default.nix` carries hand-written `boot.initrd.availableKernelModules`
   rather than a generated file:

   ```bash
   nixos-generate-config --show-hardware-config --no-filesystems
   ```

   Compare, and fold in anything missing. If the firmware's storage mode is set to
   "Intel VMD" / "RAID" rather than AHCI, the controller the NVMe disk sits behind is
   `vmd`, not `ahci` — `hosts/leto/default.nix` already carries `"vmd"` in
   `boot.initrd.availableKernelModules` for this. Without it the boot log shows
   `ahci 0000:00:0e.0: probe with driver ahci failed with error -12`; switching the
   firmware to plain AHCI also works, and either way is fine to leave `vmd` loaded.

4. **Partition. THIS DESTROYS `/dev/nvme0n1`.** disko prompts for the LUKS passphrase:

   ```bash
   sudo nix run github:nix-community/disko/latest -- \
     --mode destroy,format,mount \
     --flake /path/to/nix-config#leto
   ```

   Check `/mnt` looks right afterwards: `/`, `/home`, `/nix`, `/swap` and `/boot`.

5. Install. This builds the whole closure, so expect it to take a while on battery —
   stay on mains:

   ```bash
   sudo nixos-install --flake /path/to/nix-config#leto
   ```

   It prompts for a **root password** at the end. Set one you will remember; you need it
   in step 7.

6. `reboot`, remove the USB. You will be asked for the LUKS passphrase from step 4.

7. **Set your user password.** The config deliberately ships without one, so the greeter
   will not let you in yet. Switch to a text console with `Ctrl+Alt+F2`, log in as `root`
   with the password from step 5, then:

   ```bash
   passwd sergiusens
   ```

   Switch back with `Ctrl+Alt+F1` and log in.

## Secure Boot (lanzaboote)

Bluefin has Secure Boot on today — `bootctl status` reports `enabled (deployed)`. Stock
NixOS cannot do Secure Boot at all, so migrating without lanzaboote silently gives that
up. `modules/hardware/secure-boot.nix` is imported by `leto`.

**Do this before enrolling the TPM.** See the ordering note at the end.

1. Generate your own keys (after the first boot into NixOS):

   ```bash
   sudo sbctl create-keys
   ```

2. Rebuild, so lanzaboote signs the boot files with them:

   ```bash
   sudo nixos-rebuild switch --flake .#leto
   sudo sbctl verify          # everything under the ESP should report signed
   ```

3. Reboot into the firmware and put Secure Boot into **Setup Mode**. On this Dell that is
   Security → Secure Boot → Secure Boot Mode, or clearing the existing keys. Nothing can
   be enrolled while the firmware holds the factory keys.

4. Back in NixOS, enrol:

   ```bash
   sudo sbctl enroll-keys --microsoft
   ```

   **`--microsoft` is not optional here.** It keeps Microsoft's KEK and db alongside yours,
   which is what allows MS-signed option ROMs — Thunderbolt, the GPU, and other firmware
   blobs on Dell hardware — to keep loading. Enrolling only your own keys is a known way
   to end up with hardware that no longer initialises.

5. Reboot and confirm:

   ```bash
   bootctl status             # Secure Boot: enabled (user)
   sbctl status
   ```

If something goes wrong, Secure Boot can be turned off again in the firmware and the
machine will boot normally. That is the escape hatch; it is worth knowing it exists before
starting rather than discovering it at a dead boot screen.

### Ordering, and why it matters

Secure Boot **first**, TPM enrolment **second**.

PCR 7 measures Secure Boot state and the enrolled keys. Enrolling a TPM policy against
PCR 7 and *then* turning Secure Boot on changes that register, the TPM refuses to release
the key, and you are into the recovery key. Doing it in this order means the policy is
sealed against the state you actually intend to run.

## TPM-backed disk unlock

`leto` has a TPM 2.0 (`/dev/tpm0`, `tpm_version_major: 2`), so LUKS can unlock without
typing a passphrase at every boot. `hosts/leto/disko.nix` already passes
`tpm2-device=auto`, which is inert until a key is enrolled — with no TPM keyslot the boot
simply falls through to the passphrase prompt.

Enrolment writes to the LUKS header, so it cannot be declarative. After installing:

```bash
# ALWAYS do this first: a printable fallback, independent of the TPM
sudo systemd-cryptenroll --recovery-key /dev/nvme0n1p2

# then the TPM, with a PIN
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes /dev/nvme0n1p2
```

(Partition number per `hosts/leto/disko.nix` — the LUKS container, not the ESP.)

### Read this before deciding

**TPM-only unlock substantially weakens encryption at rest.** A stolen laptop boots
straight to the greeter and the disk is already decrypted; all that protects the data is
the login password. A passphrase at boot means the data is genuinely inaccessible.
`--tpm2-with-pin=yes` is the middle ground worth taking: a short PIN instead of a long
passphrase, with the TPM's anti-hammering making it far harder to brute force than a PIN
alone would suggest.

**Always enrol a recovery key, and keep it off the machine.** A firmware update, a BIOS
settings change or a Secure Boot state change can invalidate the PCR policy and leave the
TPM unable to release the key. Without a recovery key that is unrecoverable data loss.

**PCR choice is a trade.** Binding to PCR 7 alone (Secure Boot state) survives kernel
updates. Adding 0, 4, 8 or 9 binds the boot chain more tightly but means re-enrolling
after every kernel or bootloader change. `systemd-pcrlock` and signed PCR 11 policies are
the modern answer to that churn and are worth looking at before binding widely.

### Do Secure Boot first

PCR 7 measures Secure Boot state and the enrolled keys, so a policy sealed against it is
only worth something once Secure Boot is actually on and running your own keys — and
sealing it *before* enabling Secure Boot guarantees the policy breaks the moment you do.

lanzaboote is set up in the section above. Finish that, confirm `bootctl status` reports
Secure Boot enabled, and only then run the `systemd-cryptenroll` commands here.

## First-boot checklist

Things evaluation and building cannot verify:

```bash
# greeter found the session files (SESSION_DIRS is patched for NixOS)
#   -> Hyprland should be in ReGreet's dropdown. If not, type the command by hand:
#      uwsm start hyprland-uwsm.desktop

v4l2-ctl --list-devices        # expect "Intel MIPI Camera" at /dev/video50
wpctl status                   # expect ONE Video/Source, not thirty
systemctl status v4l2-relayd-ipu6

clinfo | grep -i "device name" # OpenCL sees the GPU (darktable/Ansel depend on it)
vainfo                         # VAAPI via iHD

swapon --show                  # expect zram AND /swap/swapfile (64 GiB)
systemctl suspend              # s2idle; confirm it resumes cleanly

lpstat -p                      # printer
scanimage -L                   # HP scanner via the hplip plugin
```

Then test **colour management** in darktable/Ansel before migrating photo work — that is
the one regression that would make this migration a bad trade, and it cannot be checked
any other way.

## Restoring individual files from Déjà Dup

Yes, and at file granularity. Déjà Dup 50.2 here uses **restic** (0.19.1), not duplicity —
confirmed from `~/.var/app/org.gnome.DejaDup/cache/deja-dup/`, which holds a restic cache
with `snapshots/` and `index/`. That matters, because restic is far better at partial
restores than duplicity ever was.

The repository: `smb://angrenost.great-torino.ts.net/cuivienen`, folder `deja-dup`,
mounted on demand through gvfs at
`/run/user/1000/gvfs/smb-share:server=…,share=cuivienen/deja-dup`. **13 snapshots**, from
2026-02-14 to 2026-10-03, the latest 429 GiB of `/var/home/sergiusens`.

### From the GUI

Déjà Dup → **Browse Backups** walks the snapshot and restores whatever you select. In
Files, right-clicking a folder offers **Restore Missing Files**.

### From the command line

The flatpak ships `restic`, and the repository was created with `--insecure-no-password`,
so no passphrase is needed:

```bash
REPO="/run/user/1000/gvfs/smb-share:server=angrenost.great-torino.ts.net,share=cuivienen/deja-dup"
R() { flatpak run --command=restic org.gnome.DejaDup --insecure-no-password --repo="$REPO" "$@"; }

R snapshots                                     # list them
R ls latest /var/home/sergiusens/.claude        # look inside one
R restore latest --target ~/restore --include /var/home/sergiusens/.claude/settings.json
R dump latest /var/home/sergiusens/.bashrc      # straight to stdout
R mount ~/backup-browse                         # browse every snapshot as a filesystem
```

`restic mount` is the pleasant one for hunting: every snapshot appears as a directory tree
and you copy out what you want.

Two things to know. Restores reproduce the **absolute path** under `--target`, so the file
above lands at `~/restore/var/home/sergiusens/.claude/settings.json`. And restoring as a
normal user prints `ignoring error for /var/home: lchown … invalid argument`, then
`Fatal: There were 1 errors` — that is only the ownership of the recreated parent
directories, which an unprivileged user cannot set. The files themselves restore
correctly; verified by diffing one against the live copy.

### Relevant to this migration

This is how `~/.claude` comes back after the reinstall. Note the snapshots store it at
`/var/home/sergiusens/...` — the ostree path — so after restoring, the project directories
still need the rename described below.

### The plan, and why none of this is in the Nix config

The existing repository was created with `--insecure-no-password` and is therefore **not
encrypted**: anyone who can read the share can read the whole backup, including
`~/.claude/.credentials.json`, SSH private keys and browser profiles.

So Déjà Dup is installed but **not configured declaratively**. The sequence is:

1. Restore what you need from the old, unencrypted repository by hand (above).
2. Set Déjà Dup up again from scratch, this time **with encryption**.
3. Point it at a share named `leto`, not `cuivienen` — the latter still carries the
   pre-rename hostname.
4. Retire the old repository once the new chain has enough history to trust.

Encryption cannot be added to an existing restic repository, so this means a fresh 429 GiB
upload and starting the snapshot history over. That is the reason the old settings are not
reproduced in `home/sergiusens/`: encoding them would make it effortless to recreate
exactly the thing being replaced.

For reference, the settings that located the old repository were `backend = 'remote'`,
`Remote.uri = 'smb://angrenost.great-torino.ts.net/cuivienen'`, `Remote.folder =
'deja-dup'`, with the SMB password in the login keyring rather than in any setting
(`secret-tool lookup protocol smb server angrenost.great-torino.ts.net user sergiusens`).

## Carrying Claude Code state across the reinstall

`~/.claude` is 36 MB here, plus `~/.claude.json` (88 KB). Both are inside `$HOME`, so
Déjà Dup covers them — but restoring the files is **not sufficient**, because of how
session history is keyed.

`~/.claude/projects/` is named by the project's absolute path with separators replaced:

```
-var-home-sergiusens-Dev-nix-config
-var-home-sergiusens-Dev-gthumb
-var-home-sergiusens-Dev-bluefin-xp
```

NixOS puts home at `/home/sergiusens`, not ostree's `/var/home/sergiusens`, so every one
of those keys changes. Restore them unchanged and Claude Code will not find the history
for any project — the sessions are intact on disk and simply never looked up. Rename them
after restoring:

```bash
cd ~/.claude/projects
for d in -var-home-sergiusens-*; do mv -- "$d" "${d/-var-home-/-home-}"; done
```

Authentication does survive: credentials are in `~/.claude/.credentials.json`, a plain
file, not the GNOME keyring — so copying `~/.claude` carries the login with it. Keep its
`0600` mode.

Worth copying as a set: `~/.claude/` (projects, memory, history.jsonl, plugins,
file-history) and `~/.claude.json`.

## Afterwards

- Add your SSH public keys to `users.users.sergiusens.openssh.authorizedKeys.keys`;
  it is empty, so remote deploys will not work until you do.
- Enable hibernation: the swapfile exists now, so read its offset and uncomment the block
  in `hosts/leto/default.nix`:

  ```bash
  sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
  ```

- Set a wallpaper for `hyprpaper` in `home/sergiusens/hyprland.nix`; it is unset.
- Rebuilds from here are just `sudo nixos-rebuild switch --flake .#leto`, and every
  previous generation stays in the boot menu.
