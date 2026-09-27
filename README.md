# homelab

A self-hosted homelab: two independent Docker Compose stacks (services + game
servers) fronted by Traefik, with scripted bootstrap, nightly backups, and
push alerting. This repository is a scrubbed snapshot of a private repo —
hostnames use `example.com`, addresses use documentation ranges, and history
is withheld. It is published as a reference layout, but everything here is
runnable on generic hardware.

## Layout

```
services/   one directory per service, each with its own docker-compose.yml
            pulled into the stack via include: in services/docker-compose.yml
games/      Minecraft (Fabric), Palworld, Sons of the Forest dedicated servers
bin/        bootstrap, backup, monitoring, deploy, and helper scripts
state/      runtime data, one dir per service (gitignored — never committed)
```

Every service follows the same pattern: a compose file with Traefik labels,
optional checked-in config, and secrets supplied via a local `.env` (copy the
adjacent `.env.example`). Mutable data lives under `state/<service>/`.

## What runs here

**Ingress & network** — Traefik (Let's Encrypt via Cloudflare DNS challenge),
AdGuard Home + Unbound for DNS, wg-easy for WireGuard VPN.

**Productivity & infra** — Forgejo (git hosting + CI runner in a gVisor
sandbox), Vaultwarden, Paperless-ngx, Mealie, Linkding, changedetection.io,
ntfy, SearXNG, Samba, Portainer (opt-in profile), Open WebUI, a QEMU VM lab.

**Media** — Plex, Jellyfin, the *arr suite (Sonarr, Radarr, Lidarr, Bazarr, Prowlarr),
qBittorrent behind a Gluetun VPN tunnel with a killswitch, SABnzbd,
Overseerr, Musicseerr, FlareSolverr.

**Chat** — Matrix (Dendrite) with the Cinny web client and LiveKit for calls.

**Games** — each under `games/`, started independently from the services
stack; world saves are part of the backup set, the multi-GB game installs are
not (they re-download).

## Quick start

```sh
./bin/install        # idempotent bootstrap: deps, docker network, ACME file,
                     # .env scaffolding, /opt/homelab symlink for the units
$EDITOR services/.env games/.env   # set your host values (see below)
cd services && docker compose config -q && docker compose up -d
cd games    && docker compose up -d
```

## Configuration

Nothing in the repo names a real domain, address, path or account. Every
host-specific value lives in **`services/.env`** (plus `DOMAIN` in
`games/.env`), scaffolded from `services/.env.example`:

| Variable | Used for |
|---|---|
| `DOMAIN` | every hostname defaults to `<sub>.${DOMAIN}` — compose labels, Traefik's `dynamic.yml` (`{{ env "DOMAIN" }}`), the Matrix web client, bin/ scripts |
| `SHARE_DIR` | storage root; media/download/export mounts default to its subdirs |
| `PUID` / `PGID` | host account that owns media (linuxserver images, Plex) |
| `LAN_IP`, `LAN_SUBNET`, `LAN_IPV6_PREFIX` | port binds (DNS, SMB, git-SSH) and the Plex/Gluetun/WireGuard/Traefik allowlists |
| `BACKUP_*`, `MONITOR_*` | backup target (host, user, dir, SSH key, pinned known_hosts, optional USB mirror) and monitored disks |
| `OPENWEBUI_LLM_URL` | any OpenAI-compatible endpoint for Open WebUI |

Required values use `${VAR:?}`, so a missing one fails `docker compose`
loudly instead of guessing. Any service can still override its own default in
`services/<svc>/.env` (each `.env.example` lists the optional keys).

Two host-side details: the systemd units in `bin/systemd/` reference
`/opt/homelab` (a symlink `bin/install` creates; the deploy unit is a template,
`homelab-deploy@<user>.timer`), and **`docker compose` must be run from the
real repo path, never through a symlink** — Compose keys bind mounts on the
logical path, so through a symlink every container looks changed and gets
recreated.

`bin/install` creates the shared external `web` network, touches
`state/traefik/acme.json` (mode 600), and scaffolds a `.env` next to every
`.env.example` for you to fill in. Point a wildcard DNS record
(`*.example.com`) at the host and set your Cloudflare API token in
`services/traefik/.env` for certificates.

## Networking model

All containers join one external `web` network; Traefik is the single ingress.
A `local-only` middleware (defined in `services/traefik/dynamic.yml`) restricts
each service to private ranges — LAN, WireGuard, Docker, and the Tailscale CGNAT
range — so only the handful of routes that opt out (with their own auth) are
reachable from the internet. Security headers are applied entrypoint-wide, and
a fail2ban jail (`bin/fail2ban/`) bans repeat 401/403 offenders using
Traefik's JSON access log.

Note: `services/traefik/dynamic.yml` is a single-file bind mount. Editors that
write atomically leave the container bound to a stale inode — after editing
it, recreate the container (`docker compose up -d --force-recreate traefik`);
a plain restart is not enough. The reverse also holds: an in-place write
hot-reloads instantly, so add any new env var the template reads to the
container (and recreate) *before* editing the file.

## Backups, monitoring, deploys

- `bin/backup` — nightly rsync snapshots of `state/`, game saves, and every
  `.env` to a remote host and a local USB mirror, with hardlink de-dup
  (`--link-dest`), pruning, and per-target failure isolation. Run from a user
  systemd timer (`bin/systemd/`).
- `bin/monitor` — 15-minute checks (disk, unhealthy containers, backup
  freshness on both targets) pushing to a self-hosted ntfy topic via a
  write-only token; `bin/notify` sends ad-hoc pushes from any LAN machine.
- `bin/deploy` — a small pull-based CD agent: fetches app repos, requires
  green CI, fast-forwards, deploys, health-checks through the real ingress,
  and rolls back on failure. Per-app config lives in `bin/deploy.d/*.conf`
  (not included in this snapshot).

## CI sandbox

The Forgejo runner executes CI jobs under gVisor (`runsc` in host-netstack
mode) on a dedicated Docker network, with a host firewall unit
(`bin/systemd/ci-net-guard.service`) blocking jobs from reaching private
address space. No docker socket, no volume mounts, no privileges. Images are
built in CI with kaniko (userspace, daemonless) — see
`services/forgejo/runner-config/config.yml`.
