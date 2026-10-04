# Migrating orthanc → thufir

Status: **backup taken, nothing migrated.** orthanc is untouched and still serving.

## Backup taken 2026-10-03

Pulled to `~/backups/orthanc-backup-20261003` on leto (51 MB), and also left in
`/var/tmp/orthanc-backup-20261003` on orthanc. All archives verified with `gzip -t`.

| File | Size | What |
| --- | --- | --- |
| `immich-pgdumpall.sql.gz` | 22M | `pg_dumpall` of the Immich cluster — role `immich`, database `immich`, UTF8 / en_US.utf8 |
| `adguardhome.tar.gz` | 17M | `/var/lib/adguardhome` — config, filter lists, query log |
| `freshrss-data.tar.gz` | 13M | `podman volume export freshrss-data` |
| `freshrss-extensions.tar.gz` | 535B | `podman volume export freshrss-extensions` |
| `tailscale.tar.gz` | 7.4K | `/var/lib/tailscale` — node identity |
| `immich.env` | 227B | **Contains DB passwords.** Not in git; keep it that way |
| `etc-containers-systemd.tar.gz` | 1.4K | the quadlets as actually deployed |

A `pg_dumpall` was used deliberately rather than copying `/var/lib/immich/db`. A
Postgres data directory is not portable across versions, and that volume is on a
pinned image carrying vectorchord and pgvecto.rs.

**The backup lives on two machines that are both scheduled for reinstallation.**
Put a copy somewhere else before either migration.

## Facts confirmed on the running server

- Local state is small: Immich DB 325M, AdGuard 104M, tailscale 40K. `/var` has
  212 GB free, so there is ample room to work in place.
- `/etc/immich/env` holds `POSTGRES_USER=immich`, `POSTGRES_DB=immich`,
  `POSTGRES_INITDB_ARGS=--data-checksums`, `DB_USERNAME=immich`,
  `DB_DATABASE_NAME=immich`, two password keys, and:
- **`DB_HOSTNAME=localhost` and `REDIS_HOSTNAME=localhost`** — because orthanc
  ran Immich in a podman *pod*, so the containers shared a network namespace.
  `hosts/thufir/default.nix` uses a network instead, since nixpkgs'
  `oci-containers` has no pod support. **Both values must change** to
  `immich-db` and `immich-redis` when the env file is re-encrypted into
  `secrets/thufir.yaml`.
### The NAS mount is hung, and the watchdog never noticed

Measured on orthanc, 2026-10-03:

```
ls /var/mnt/nas    -> exit 124 after 12s   (timed out)
mountpoint -q      -> exit 124 after  5s   (blocks too)
/proc/mounts       -> 192.168.0.101:/orthanc on /var/mnt/nas nfs4 ... soft,timeo=100
```

The NAS itself is fine — from leto it answers NFS v2/v3/v4, SMB, SSH and both
web UIs, and exports `/orthanc` to `192.168.0.100` only. It is orthanc's client
mount that is wedged, most likely stale NFSv4 state after a NAS reboot.

**The watchdog has been failing silently for weeks.** Its first line is

```sh
if ! timeout 5 mountpoint -q /var/mnt/nas; then exit 0; fi
```

On a hung mount `mountpoint` blocks, `timeout` kills it with exit 124, the `!`
turns that into true, and the script decides the path is not a mountpoint and
exits 0. Every run in the journal "Deactivated successfully" after exactly five
seconds. It has never once remounted anything.

`hosts/thufir/default.nix` fixes this: the mounted-or-not test reads
`/proc/mounts`, which cannot block, and only the liveness test is allowed to
time out.

Consequences visible right now on orthanc:

- **luanti: 2168 failed starts.** Its volume is on the hung mount, so the
  container start times out, systemd restarts it, forever.
- **Immich's photo storage is on that mount too** (`/var/mnt/nas/immich/upload`).
  The containers have been up five weeks and started when the mount was alive;
  anything touching storage since is suspect.

To recover orthanc without reinstalling anything:

```bash
sudo umount -l /var/mnt/nas
sudo systemctl stop var-mnt-nas.mount
ls /var/mnt/nas          # automount re-establishes on access
```

Worth doing regardless of the migration — and worth confirming Immich is
actually healthy afterwards.

## Order of work

1. Copy the backup somewhere that is not leto or orthanc.
2. Recover the hung NFS mount on orthanc (above). The NAS is healthy; the
   client mount is wedged, and the watchdog meant to catch that is broken.
3. Generate `hosts/thufir/hardware-configuration.nix` on the real machine, and
   confirm the LAN interface name — `enp0s20f0u3` is a USB NIC.
4. Re-encrypt `/etc/immich/env` into `secrets/thufir.yaml` with the two
   hostnames changed, once `.sops.yaml` has real age keys.
5. Install NixOS, let the containers come up with an empty database, then stop
   `immich-server` and restore:
   `zcat immich-pgdumpall.sql.gz | podman exec -i immich-db psql -U immich`
6. Unpack AdGuard's directory and import the FreshRSS volumes with
   `podman volume import`.
7. `tailscale up` to re-enrol; the old node identity can be discarded.

## Rollback

orthanc is a bootc system: its previous deployment is still in the boot menu,
and nothing here has modified it. Until its disk is overwritten, rollback is a
reboot.
