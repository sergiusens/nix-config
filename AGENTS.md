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

- **Hyprland**, not GNOME. The compositor, greeter (`greetd` + **ReGreet** in `cage`) and
  portals are system-level in `modules/desktop/hyprland.nix`; appearance, input and
  keybinds are per-user in `home/sergiusens/hyprland.nix`. Do not install Hyprland twice —
  the home-manager module sets `package = null` on purpose.
- The `programs.regreet` module sets `services.greetd.enable` and the session command
  itself, both with `mkDefault`. Never set `services.greetd.settings.default_session.command`
  alongside it: a plain definition silently wins and launches the wrong greeter.
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

## Validating a Hyprland config

Hyprland renames and removes config options between releases, and neither `nix build` nor
evaluation catches it — a stale option only surfaces as a red banner at runtime. The
Hyprland package ships its own answer key:

- `share/hypr/stubs/hl.meta.lua` — every valid config key, as `---| "section.key"` lines
- `share/hypr/hyprland.lua` — the upstream default config, which shows current idiom

Extract the valid keys and diff them against the generated config rather than guessing at
renames:

```bash
# valid keys
grep -oE '^---\|\s*"[a-z0-9_.:-]+"' .../share/hypr/stubs/hl.meta.lua
# what we generate
nix eval --raw .#nixosConfigurations.leto.config.home-manager.users.sergiusens\
  .xdg.configFile.\"hypr/hyprland.conf\".source
```

Three caveats, each learned the hard way:

- **The stubs list LUA key names, which are not always the hyprlang spelling.** They are
  normalised to underscores. `input.touchpad.tap_to_click` in the stubs is
  `tap-to-click` in hyprlang, and "correcting" it to the stub spelling makes Hyprland
  reject the option outright. Use the stubs to decide whether a setting still *exists*,
  never to decide how to *spell* it in hyprlang. For spelling, check
  `share/hypr/hyprland.lua` and the wiki, or simply believe an option that Hyprland is
  not complaining about.
- `bezier` and `animation` are hyprlang **keywords**, not config keys, so they are absent
  from the stubs and that is correct. Same for `bind`, `monitor`, `exec-once`, `gesture`.
- Dispatchers are not config keys either. Check them against `hl.dsp.*` in the default
  Lua config: `togglesplit` is `hl.dsp.layout("togglesplit")`, i.e. `layoutmsg,
  togglesplit` in hyprlang, not a top-level dispatcher.

Corollary: a config option Hyprland does **not** complain about is working. Do not go
looking for silent failures that the stubs merely appear to imply.

## Vendored code

`modules/work/falcon-sensor.nix` and the two `falcon-sensor-*.sh` scripts are vendored
verbatim from <https://github.com/wimpysworld/nix-config> under the Blue Oak Model
License. **Do not reformat, refactor or "clean up" those three files** — keeping them
byte-identical is what makes it possible to diff against upstream and pull in fixes.
`modules/work/ATTRIBUTION.md` records the pinned commit and checksums; keep it in place,
since the licence requires the notice to travel with the code.

Fleet-specific configuration goes in `modules/work/policy.nix`, which is ours.

## Facts worth knowing

- `thufir` holds a static `192.168.0.100` and serves LAN DNS via AdGuard Home, bound to
  explicit addresses because a wildcard `:53` collides with the systemd-resolved stub.
- `shadout` is an appliance at `192.168.0.101`, not a Nix-managed host. It exports NFS,
  which `thufir` mounts at `/var/mnt/nas` via an automount unit with an NFS watchdog timer.
- `leto` and `jessica` both drive an HP printer/scanner needing the proprietary HPLIP
  plugin — in `bluefin-xp` this is a binary overlay under `/usr`, which is the kind of
  thing Nix handles far better.
- `leto` is the machine this repository is usually edited from.
