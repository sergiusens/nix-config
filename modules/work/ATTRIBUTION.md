# Attribution

`falcon-sensor.nix`, `falcon-sensor-install.sh` and `falcon-sensor-check.sh` in this
directory are vendored **verbatim** from a colleague's configuration:

- Source: <https://github.com/wimpysworld/nix-config>
- Commit: `c7e4c2c9e1e8234021b1649815294b42eebdbf6a`
- Paths: `modules/nixos/falcon-sensor.nix`, `nixos/_mixins/policy/falcon-sensor-install.sh`,
  `nixos/_mixins/policy/falcon-sensor-check.sh`
- Licence: **Blue Oak Model License 1.0.0** — <https://blueoakcouncil.org/license/1.0.0>

Vendored rather than retyped so the tested logic arrives byte-for-byte. SHA-256 of the
files as fetched:

```
4865039e82760910cf7574289513c7916899672e6b19f75b6f25f1eceac1f3f6  falcon-sensor.nix
4ab5b47fdca264c9b55c3058b7c550c3a9fc4337a8f7f2aca0ea9d5b7f2df784  falcon-sensor-install.sh
e30d97c24746ca7052eb306d4e66522c7408973f514cf0d35908c592fb792032  falcon-sensor-check.sh
```

Blue Oak requires that anyone receiving a copy of this software also receives the licence
text or a link to it. That obligation is met by this file; keep it alongside the vendored
sources, and keep it in place if this repository is published.

## Why vendored rather than taken as a flake input

His modules are coupled to his repository's own `noughty` library and host-tag registry.
`modules/nixos/falcon-sensor.nix` happens to be self-contained — it takes only `config`,
`lib` and `pkgs` — so it drops in cleanly, whereas his policy mixin does not.

The cost is that upstream fixes do not arrive automatically. He is actively maintaining
this against a moving target (sensor 7.38's tamper protection, RFM on kernel mismatch), so
**re-check the upstream commit before debugging anything here** — the bug may already be
fixed. The better long-term answer is to ask him to factor the module and scripts into a
small shared flake that you both consume.

## What is NOT vendored

- `policy.nix` is ours: the fleet-specific glue, sops wiring and Kolide configuration.
- His `kolide-xdg-open.sh` logging wrapper is omitted. It works around
  kolide/launcher#2430, where tray menu clicks invoke `xdg-open` with output discarded and
  the exit status unchecked, and it depends on his Wayland-compositor registry. The PATH
  handling it relies on is reproduced in `policy.nix`; the logging is not.
