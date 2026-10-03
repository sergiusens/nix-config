# Fleet naming

Canonical host roster. **This file is the source of truth for hostnames** — anything
else that names a machine (flake outputs, `networking.hostName`, SSH config, Tailscale
ACLs, `/etc/hosts`) must agree with the table below.

## Theme

House Atreides, from Frank Herbert's *Dune* (1965) — characters and titles, not planets.

The fleet is framed as the Duke's **household**, not a family tree. Dune cannot supply a
father with two sons (Leto has only Paul; Paul's children are the twins Leto II and
Ghanima), so literal genealogy was abandoned in favour of the household, which also frees
up the two best functional names — `thufir` and `shadout`.

Replaces a previous Tolkien place-name scheme (Cuiviénen, Eregion, Lindon, Orthanc,
Angrenost). Continuity with it was deliberately dropped.

## Roster

| Host | Machine | Base image today | Role |
| --- | --- | --- | --- |
| `leto` | desktop | `ghcr.io/ublue-os/bluefin-dx:stable` | Photo workstation — Intel OpenCL, rapid-photo-downloader, HPLIP scanner, podman.socket |
| `kynes` | laptop | `ghcr.io/ublue-os/bluefin-dx:stable` | Work laptop — Chrome, CrowdStrike Falcon, Kolide launcher |
| `jessica` | laptop | `ghcr.io/ublue-os/bluefin:stable` | Wife's laptop — Chrome, CrossOver via distrobox, HPLIP |
| `duncan` | laptop | — (new) | Son's laptop |
| `gurney` | laptop | — (new) | Son's laptop |
| `thufir` | server | `ghcr.io/ublue-os/ucore:stable` | Immich, AdGuard Home (DNS), FreshRSS, Luanti, Tailscale. Static `192.168.0.100` |
| `shadout` | NAS | — (appliance) | NFS bulk storage, `192.168.0.101`. Exports `/orthanc`, mounted by `thufir` at `/var/mnt/nas` |

Domain / tailnet: **`atreides`** — every host is a member of the house, e.g.
`thufir.atreides`, `jessica.atreides`.

## Rationale

- **`leto`** — Duke Leto Atreides, head of the household. The seat of the house, so the
  primary workstation.
- **`kynes`** — Liet-Kynes, Imperial Planetologist on Arrakis and secretly the Fremen's
  leader: a man drawing an Imperial salary while serving other ends. Exactly a
  work-issued laptop running corporate EDR and MDM in your home. Accurate without being
  an insult, and Kynes is an admirable figure.
- **`jessica`** — the Lady Jessica, Bene Gesserit, the Duke's lady.
- **`duncan`** / **`gurney`** — Duncan Idaho, Swordmaster of Ginaz, who goes out and always
  returns; Gurney Halleck, warrior-troubadour with his baliset. In the book these are the
  two men who train and protect the Duke's son, which is a better story for the sons'
  machines than two arbitrary worlds.
- **`thufir`** — Thufir Hawat, Mentat. In Dune a Mentat is a human trained as a computer,
  because thinking machines are forbidden; he holds every record and computes every
  projection, and as Master of Assassins he is also the house's security. The best
  character-to-machine mapping in the book for a server that stores the household's
  archive and filters its DNS.
- **`shadout`** — a Fremen *title*, not a name: it means **well-dipper**. Shadout Mapes is
  the Arrakeen housekeeper, the one who draws water from the well. A name that literally
  means "one who draws the precious resource from storage", for a file server.

## Conventions

- Lowercase, no digits, no separators. Single word.
- **First letters are all distinct** — `l k j d g t s` — so shell tab-completion resolves
  in one keystroke. Preserve this property when adding hosts.
- Prefer short names for machines reached over SSH.
- Physical/owned machines get character names. If a future host's *function* must be
  unmistakable, an object or title from the Dune glossary is an acceptable exception —
  `thumper` for monitoring/alerting (a device that beats a rhythmic signal to summon
  attention), `solido` for anything image-serving, `paracompass` for a router.

## Migration map

Old Tolkien name → new name. Needed when porting anything out of the `bluefin-xp`
repository, which still uses the old names as image names, build-script filenames, and
`ujust` recipe names.

| Old | New |
| --- | --- |
| `cuivienen` | `leto` |
| `eregion` | `kynes` |
| `lindon` | `jessica` |
| `orthanc` | `thufir` |
| `angrenost` | `shadout` |
| — | `duncan` (new) |
| — | `gurney` (new) |

Note `var-mnt-nas.mount` in `bluefin-xp` describes itself as the "Angrenost orthanc
share" — that becomes the `shadout` export mounted by `thufir`.

## Reserved

Unassigned, consistent with the theme, first letter noted for the distinctness rule:

`paul` (p), `alia` (a), `stilgar` (s¹), `chani` (c), `harah` (h), `otheym` (o), `korba` (k¹),
`irulan` (i), `hayt` (h¹), `mohiam` (m), `mapes` (m¹), `yueh` (y), `piter` (p¹),
`rabban` (r), `feyd` (f), `shaddam` (s¹).

¹ collides with an assigned host or another reserved name — check before use.

The Harkonnen names (`rabban`, `piter`, `feyd`) are held back for machines you dislike.

## Variants considered

Recorded so they are not relitigated:

- **`yueh` instead of `kynes`** for the work laptop — the trusted insider who betrayed the
  house because an outside power held leverage on him. More pointed about corporate EDR,
  but names the daily work machine after the traitor. Rejected on temperament.
- **`paul` instead of `gurney`** for a son's laptop — more iconic, puts the actual heir's
  name in the fleet; `gurney` is the warmer character. Still available as a swap.
- **`mapes` instead of `shadout`** — three characters shorter, but loses the well-dipper
  meaning that justifies the name. Rejected.
- **Planet names** (`arrakis` as the domain, with `richese`, `ix`, `caladan`, `ginaz`,
  `tupile`, `tabr`, `windtrap`) — kept continuity with the Tolkien place-names and paired
  the two `-dx` machines as Dune's two rival machine cultures. Rejected once continuity
  stopped mattering: character names encode ownership, which a family fleet needs, and
  that scheme had a `tabr`/`tupile` first-letter collision plus a two-character hostname.
