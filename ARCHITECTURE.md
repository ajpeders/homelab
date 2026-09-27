# Architecture

This is a concise map of the system. Full rationale, gotchas, and edge cases
live in [CLAUDE.md](CLAUDE.md) (the source of truth) — this file just
orients you before you go there. Per-service specifics are in
[SERVICES.md](SERVICES.md); operational steps are in [HOWTO.md](HOWTO.md).

## System overview

Two independent Docker Compose stacks on one home server:

- **`services/`** — productivity/infra/media/chat services (Traefik, AdGuard,
  Forgejo, Plex, Matrix, the `*arr` stack, myproject, etc.), listed in
  [README.md](README.md#services) and detailed in [SERVICES.md](SERVICES.md).
- **`games/`** — Minecraft (vanilla + ATM10, only one runs at a time — see
  `bin/mc-switch`), Sons of the Forest, Palworld.

Each stack has its own `docker-compose.yml` that `include:`s per-service
compose files, and is brought up independently from its own directory.

Other top-level directories:

- **`apps/`** — source of truth for app-backed services built from their own
  repos (dashboard, jetstream, myproject, discord/matrix bots, etc.); cloned
  via `bin/clone-apps.sh`. The compose file under `services/<svc>/` is either
  a thin wrapper or the root stack includes the app's compose directly.
- **`state/`** — gitignored, mutable runtime data (volumes, logs, databases)
  mounted from `../../state/<service>/` relative to each service.
- **`bin/`** — operational scripts (install, backup, deploy, monitor, idle
  shutdown, VPN, etc.) plus their systemd unit sources in `bin/systemd/`.

## Network / data flow

```
Internet ──► Traefik (websecure:443) ──► service container (on `web` network)
Internet ──► Traefik (web:80) ──► redirect to 443
LAN/VPN ────► Traefik / direct ports (Samba, DNS, Minecraft, game UDP ports)
```

- **Ingress**: Traefik is the single entry point for HTTP(S) services, routed
  by container labels. Certificates come from Let's Encrypt via Cloudflare
  DNS-01 challenge. Hostnames all derive from one `DOMAIN` (`services/.env`,
  `games/.env`) as `<sub>.${DOMAIN}`; a service's `*_DOMAIN` overrides its own.
- **Access control**: the `local-only@file` Traefik middleware
  (`services/traefik/dynamic.yml`) restricts most routers to RFC1918 + VPN
  ranges (LAN, WireGuard `10.9.0.0/24`, Tailscale `100.64.0.0/10`, the Docker
  `web` network). A short list of services is intentionally public — see
  "Publicly exposed" in [SERVICES.md](SERVICES.md). `security-headers@file`
  is applied to every websecure router.
- **Docker network**: all service containers share one externally-created
  `web` network; Traefik is the only thing that needs to reach most of them
  from outside it.
- **State**: every service's persistent data lives under `state/<service>/`,
  gitignored and never committed. This is also the unit backups act on.
- **Non-Docker backends**: `services/traefik/dynamic.yml` can also route to
  plain LAN hosts (e.g. a Pi) via a `routers:`/`services:` pair with a plain
  `url:` — no container needed.

## Key decisions

- **Two independent stacks, not one.** `services/` and `games/` don't share
  a compose project, so game servers (which hog RAM) can't destabilize the
  core infra stack and vice versa.
- **CI/CD is two-stage and deliberately split.** CI (test/build gate) runs in
  a hardened, sandboxed `forgejo-runner` (gVisor + no docker socket + no
  volume mounts — see "CI job sandbox" in CLAUDE.md) so untrusted job code
  never touches the host. CD (`bin/deploy`, a systemd timer) runs separately
  as a trusted user, requires the deployed commit's CI status to be green,
  and rolls back on a failed health check. This keeps the sandboxed compute
  and the privileged deploy path from ever being the same process.
- **Apps that build from source live outside this repo.** Each is its own
  git repo under `apps/<name>/`, deployed by `bin/deploy`; this repo only
  holds the compose wrapper and config. Keeps app source history and CI
  separate from infra changes.
- **Backups are file-level, not volume snapshots**, via rsync with
  `--link-dest` hardlink dedup to two independent targets (offsite host +
  local USB), so no single target's failure blocks the other.
- **Alerting uses three separate ntfy topics** (`homelab-alerts`,
  `homelab-notify`, `homelab-media`) with distinct, least-privilege tokens,
  so a compromised low-trust component (e.g. an `*arr` app) can't publish to
  the channel real alerts use.
- **The daily digest also covers ArchDesktop** without installing anything
  there: `bin/digest` streams `bin/probe-backup-host` over `ssh arch-alex bash -s`
  and appends its output (failed units, grouped journal errors, coredumps,
  backup freshness).
  The ssh call is bounded, so a sleeping desktop reports `unreachable`
  instead of stalling the digest.
- **Portainer is opt-in** (`--profile admin`), not part of the default
  stack, because it holds Docker-socket access.

For the detailed "why" behind any of the above — including known sharp edges
(Traefik's single-file bind-mount gotcha, gVisor networking quirks, the
`ci-jobs` firewall's conntrack rule, etc.) — see [CLAUDE.md](CLAUDE.md).
Current known issues and planned work are tracked in
[ROADMAP.md](ROADMAP.md).
