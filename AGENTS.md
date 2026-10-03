# nix-config

Declarative Nix configuration for a seven-machine personal fleet: one workstation, four
laptops, a home server, and a NAS appliance.

## Status

A flake with two host configurations, shared modules, and home-manager. Neither host
has been built or booted yet.

Flakes only see files git **tracks**, so `git add` a new file before expecting
`nix build`, `nixos-rebuild --flake`, or any flake evaluation to find it. An untracked
`flake.nix` fails with a confusing "does not provide attribute" rather than a missing-file
error.

`bluefin-xp` (`../bluefin-xp`) is the reference for what each host actually does:
per-host build scripts, quadlet container units, systemd mounts, and `ujust` recipes.
Translate from it rather than copying, and mind the hostname migration map.

**Decided:** `leto` and `kynes` become full NixOS hosts, with **Hyprland** replacing
GNOME. The other five machines stay on bootc for now. Nothing in this repo has been
evaluated — Nix is not installed on `leto`. See README.md.

## Hostnames

**[HOSTNAMES.md](./HOSTNAMES.md) is the source of truth for the host roster.** Read it
before naming anything.

The fleet is named after House Atreides characters from Frank Herbert's *Dune*:
`leto`, `kynes`, `jessica`, `duncan`, `gurney`, `thufir`, `shadout`, on the domain
`atreides`.

When working in this repo:

- Never invent a hostname. Use one from the roster, or add it to HOSTNAMES.md first.
- Hostnames in Nix code (`networking.hostName`, `nixosConfigurations.*`, directory names
  under `hosts/`, SSH config, Tailscale ACLs) must match HOSTNAMES.md exactly.
- The roster's first letters are all distinct (`l k j d g t s`) so tab-completion resolves
  in one keystroke. Preserve that when adding a host.
- `bluefin-xp` still uses the old Tolkien names (`cuivienen`, `eregion`, `lindon`,
  `orthanc`, `angrenost`). HOSTNAMES.md has the migration map. Translate when porting;
  do not copy old names forward.

## Desktop conventions

- **Hyprland**, not GNOME. The compositor, greeter (`greetd` + `tuigreet`) and portals are
  system-level in `modules/desktop/hyprland.nix`; appearance, input and keybinds are
  per-user in `home/sergiusens/hyprland.nix`. Do not install Hyprland twice — the
  home-manager module sets `package = null` on purpose.
- **Ghostty** is the terminal. `foot` is installed alongside as a rescue terminal on a
  separate keybind, sharing none of Ghostty's GPU/GTK dependencies.
- The keyboard is **`latam`**. Hyprland does not read `services.xserver.xkb`, so the
  layout must be set in the compositor's own `input.kb_layout` as well.
- `leto` is a **laptop** (Dell XPS 13 Plus 9320), not a desktop, despite being the
  photo workstation.

## Secrets

**Nothing secret goes in this repository in plaintext.** Use `sops-nix` or `agenix`.

`bluefin-xp` is a cautionary example — `orthanc.ign` and `orthanc.bu` carry a live GitHub
PAT (base64-encoded in an `/etc/ostree/auth.json` blob), a Tailscale auth key, and a user
password hash, all committed. Those tokens need rotating, and when porting that host's
config here the credentials must move behind encrypted secrets rather than being copied.

Specifically do not commit: registry auth JSON, Tailscale auth keys, the CrowdStrike CID,
Kolide enrollment secrets, cosign private keys, or password hashes.

## Facts worth knowing

- `thufir` holds a static `192.168.0.100` and serves LAN DNS via AdGuard Home, bound to
  explicit addresses because a wildcard `:53` collides with the systemd-resolved stub.
- `shadout` is an appliance at `192.168.0.101`, not a Nix-managed host. It exports NFS,
  which `thufir` mounts at `/var/mnt/nas` via an automount unit with an NFS watchdog timer.
- `leto` and `jessica` both drive an HP printer/scanner needing the proprietary HPLIP
  plugin — in `bluefin-xp` this is a binary overlay under `/usr`, which is the kind of
  thing Nix handles far better.
- `leto` is the machine this repository is usually edited from.
