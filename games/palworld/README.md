# Palworld Dedicated Server

Official Palworld dedicated server (Steam app `2394010`) via the community
[`thijsvanloef/palworld-server-docker`](https://github.com/thijsvanloef/palworld-server-docker)
image. Follows the same direct-UDP-publish pattern as `sons-of-the-forest/`
(not routed through Traefik — game traffic is UDP).

## Setup

```sh
cd games/palworld
cp .env.example .env      # then set ADMIN_PASSWORD (and SERVER_PASSWORD if wanted)
docker compose up -d      # or from games/: docker compose up -d palworld
```

First boot downloads the server (~a few GB) into `./game`, so give it a couple
of minutes before the healthcheck goes green.

## Ports (open on the router/firewall to expose publicly)

| Port        | Proto | Purpose        |
|-------------|-------|----------------|
| 8211        | UDP   | Game traffic   |
| 27015       | UDP   | Steam query    |

Connect from the Palworld client via **Join with IP** → `<host-ip>:8211`.

## Idle auto-stop

`bin/palworld-idle` (every 10 min via `homelab-palworld-idle.timer`) polls RCON
`ShowPlayers` and stops the container after **72 consecutive empty checks
(~12 hours)**, saving via RCON first. That reclaims the several GB the server
holds whether or not anyone is playing.

**Starting it back up is manual** — there is no wake-on-demand for a UDP game
port, so an auto-start would just mean "always running" again. Tap it on the
dashboard (`palworld` is in `POWER_ALLOWLIST`) or:

```sh
cd games && docker compose up -d palworld
tail state/palworld/idle.log      # every stop/skip decision + why
```

The script will not stop a server it could not actually poll: an RCON error is
treated as *unknown*, not *empty*, and a container up for less than
`PALWORLD_MIN_UPTIME_S` (default 600s) is skipped entirely so a booting server
— SteamCMD update plus world-gen, with RCON refusing connections throughout —
is never mistaken for an idle one. Tunables: `PALWORLD_IDLE_CHECKS`,
`PALWORLD_MIN_UPTIME_S`.

Because this stops a container whose restart policy is `unless-stopped`,
`palworld` is also in `bin/monitor`'s `IGNORE_DOWN` — otherwise the monitor
would alert every 15 min that it is unexpectedly down.

Install (sudo):

```sh
sudo cp bin/systemd/homelab-palworld-idle.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now homelab-palworld-idle.timer
```

## Starting a fresh world

The world lives in `game/Pal/Saved/SaveGames/0/<GUID>/`, and
`game/Pal/Saved/Config/LinuxServer/GameUserSettings.ini` pins which GUID loads
via `DedicatedServerName`. To retire a world and generate a new one:

```sh
docker exec palworld rcon-cli "Save" && docker exec palworld backup
# copy the resulting /palworld/backups/*.tar.gz somewhere OUTSIDE game/ first —
# state/palworld/world-archive/ is good, since state/ is in the nightly backup
docker stop palworld
# remove the world dir AND GameUserSettings.ini, so a new GUID is generated
docker compose up -d palworld
```

Verify the archive contains `Level.sav` before deleting anything. Note the
in-image backup tarball is much smaller than the world directory (~240 KB vs
~7 MB) — that is expected: the directory is mostly the game's own rolling
`backup/world/` snapshot history, which the tarball excludes.

## Notes

- **RAM-hungry.** Budget ~8 GB and expect it to grow — the server leaks memory
  over long uptimes. A nightly in-container restart is scheduled
  (`RESTART_CRON_EXPRESSION`, 04:00) to keep it in check, and `bin/palworld-idle`
  stops it outright when empty.
- **Backups** run in-container every 6h into `./game` (`DELETE_OLD_BACKUPS`,
  7-day retention). This is separate from the homelab nightly `bin/backup`,
  which does not cover `games/` world saves.
- `game/` and `.env` are gitignored (large runtime data / secrets).
- Pinned to a specific image tag in `docker-compose.yml`; bump deliberately.
