# HOWTO

Step-by-step guides for common tasks in this repo. Background and rationale
live in [CLAUDE.md](CLAUDE.md) and [ARCHITECTURE.md](ARCHITECTURE.md); the
full service list is in [SERVICES.md](SERVICES.md).

## Fresh deploy on a blank server

See [QUICKSTART.md](QUICKSTART.md) for the full walkthrough
(`./bin/install` → fill in `.env`s → `./bin/clone-apps.sh` → bring up each
stack). This section only covers day-to-day tasks.

## Configure a new host (host-specific values)

Everything host-specific lives in **`services/.env`** (plus `DOMAIN` in
`games/.env`); nothing in the repo names a real domain, IP, path or account.
`bin/install` scaffolds it from `services/.env.example` and warns while
`DOMAIN` is still `example.com`.

1. Set `DOMAIN`, `SHARE_DIR`, `PUID`/`PGID`, `LAN_IP`, `LAN_SUBNET` (and
   `LAN_IPV6_PREFIX` on a dual-stack LAN) in `services/.env`. Every hostname
   defaults to `<sub>.${DOMAIN}` and every media mount to `${SHARE_DIR}/…`; a
   missing required value fails `docker compose` loudly instead of guessing.
2. Set the `BACKUP_*` block (remote host/user/dir, SSH key, pinned
   known_hosts, optional USB mount) and `MONITOR_MOUNTS`. Seed the host key:
   `ssh-keyscan -t ed25519,rsa <host> > <BACKUP_KNOWN_HOSTS>`.
3. Override a single service only when needed, in `services/<svc>/.env`
   (e.g. `PLEX_DOMAIN`, `SONARR_MEDIA_PATH`) — each `.env.example` lists them.
4. Let `bin/install` create the `/opt/homelab` symlink, then install units
   from `bin/systemd/` (the deploy unit is a template: `homelab-deploy@<user>.timer`).
   fail2ban: copy `bin/fail2ban/homelab-own.local.example` to
   `/etc/fail2ban/jail.d/homelab-own.local` with your own public IPs.
5. Verify: `cd services && docker compose config -q` (no "required variable"
   errors). Run compose from the **real** repo path, never through a symlink —
   see CLAUDE.md.

## Add a new service to `services/`

1. Create `services/<name>/docker-compose.yml` with the service definition
   and Traefik labels (routing, and `local-only@file` unless it's meant to
   be public — see "Publicly exposed" in [SERVICES.md](SERVICES.md)).
2. If it needs secrets, add `services/<name>/.env.example` (checked in,
   placeholder values only) — never commit the real `.env`.
3. Mount any persistent data under `../../state/<name>/` (relative to the
   service directory) so it's covered by backups and stays gitignored.
4. Register it in `services/docker-compose.yml`'s `include:` list:
   ```yaml
   - path: ./<name>/docker-compose.yml
     env_file: ./<name>/.env
   ```
5. If it builds from its own source repo instead of a published image, put
   the source under `apps/<name>/` (its own git repo), add it to
   `bin/clone-apps.sh`'s `APPS` list, and include `../apps/<name>/docker-compose.yml`
   instead.
6. Add a row to the service table in [README.md](README.md) and an entry in
   [SERVICES.md](SERVICES.md).
7. Bring it up: `cd services && docker compose up -d <name>`.

## Deploy an app-backed service (CD)

App source repos (`apps/<name>/`) are deployed automatically by
`bin/deploy`, run every 3 minutes via `homelab-deploy@<user>.timer`. It only
deploys when the tracked branch is ahead **and** the tip commit's Forgejo CI
status is green.

```sh
./bin/deploy                     # run the CD agent now, all apps
./bin/deploy <name>               # just one app
tail state/deploy/deploy.log      # decision log: every deploy/skip/block + why
cat state/deploy/<name>.log       # per-app build/deploy output
```

To onboard a new app to CD, add `bin/deploy.d/<name>.conf` (see existing
files there, e.g. `jetstream.conf`, for `APP_DIR`, `BRANCH`, `FORGEJO_REPO`,
`DEPLOY_CMD`, `HEALTH_CMD`).

## Check CI status for a repo/PR

CI runs via Forgejo Actions (`.forgejo/workflows/ci.yml` in each repo) on the
sandboxed runner. Check status with a personal access token (Forgejo →
Settings → Applications → Access Tokens):

```sh
export FORGEJO_TOKEN=<your-personal-access-token>
curl -s -H "Authorization: token $FORGEJO_TOKEN" \
  "http://localhost:3000/api/v1/repos/<owner>/<repo>/issues/<pr>/labels"
```

This repo's own CI (`.forgejo/workflows/ci.yml`) shellchecks `bin/*` and
validates `docker compose config` on both stacks on every push to `main`.

## Update a service

```sh
docker compose -f services/<name>/docker-compose.yml pull
docker compose -f services/<name>/docker-compose.yml up -d
```

For an app-backed service whose source changed, rebuild instead of pulling:
`docker compose -f services/<name>/docker-compose.yml build`.

## Run a backup manually / check backup health

```sh
./bin/backup                                 # run now
tail -f state/backup.log                     # watch progress
systemctl --user status homelab-backup.timer # timer status (run as ween)
ssh backup-host "ls /mnt/storage/backups/"     # list remote snapshots
```

See "Backup" in [CLAUDE.md](CLAUDE.md) for what's included/excluded and the
known failure modes.

## Check monitoring / send an alert

```sh
./bin/monitor                                   # run the checks now
cat state/monitor/active-alerts                 # currently-active problems
./bin/ntfy-alert default tada "test" "hello"    # send an ad-hoc test alert
./bin/notify "message"                          # ad-hoc ping from any device (homelab-notify topic)
```

## Bring everything up after a reboot

```sh
cd services && docker compose up -d
cd ../games && docker compose up -d
```

## Check what's running

```sh
docker ps --format "table {{.Names}}\t{{.Status}}" | sort
```
