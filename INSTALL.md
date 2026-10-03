# Installing

For `leto`. `kynes` needs a real `hardware-configuration.nix` first — see README.md.

## Try it in a VM before touching the laptop

This costs nothing and answers the questions that matter: does ReGreet come up, does
Hyprland appear in its session dropdown, do the keybinds work, is the font legible.

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
remote-viewer vnc://localhost:5900     # virt-viewer is already installed on Bluefin
podman stop leto-vm                    # when done
```

`/dev/kvm` is world-writable on Bluefin, so no group membership is needed. The qcow2 lands
in `~/.cache/leto-vm`; delete it to start from a clean disk.

### What to look for

- ReGreet appears, legibly, at a sensible size — the whole reason it replaced tuigreet.
- **Hyprland is in the session dropdown.** If the list is empty, the `SESSION_DIRS` fix in
  `modules/desktop/hyprland.nix` did not take; type `uwsm start hyprland-uwsm.desktop`
  by hand to get in, and the setting needs revisiting.
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

   Compare, and fold in anything missing.

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
