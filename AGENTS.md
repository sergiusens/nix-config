# nix-config

Declarative Nix configuration for a seven-machine personal fleet: one workstation, four
laptops, a home server, and a NAS appliance.

## Status

**Pre-baseline.** This repository currently contains documentation only — no `flake.nix`,
no host modules, no Nix code yet.

Flakes only see files git **tracks**, so `git add` a new file before expecting
`nix build`, `nixos-rebuild --flake`, or any flake evaluation to find it. An untracked
`flake.nix` fails with a confusing "does not provide attribute" rather than a missing-file
error.

Every machine in the fleet runs a **bootc / Universal Blue** image today, built by the
separate `bluefin-xp` repository (`../bluefin-xp`), not NixOS. That repo is the reference
for what each host actually does: per-host build scripts, quadlet container units,
systemd mounts, and `ujust` recipes.

One decision is still open and blocks the shape of the baseline:

- **Full NixOS hosts** — replace bootc entirely. Highest leverage, but `kynes` loses the
  CrowdStrike Falcon and Kolide packaging that currently depends on RPM and SELinux
  equivalency rules.
- **Nix + home-manager layered on Bluefin** — keep bootc for the OS, manage packages and
  dotfiles declaratively on top.
- **Split** — NixOS on `thufir`, where it buys the most, and Nix-on-Bluefin elsewhere.

Do not pick one unilaterally.

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
