# Heroku Buildpack: Caddy Edge

Ships a Caddy binary with rate limiting and HTTP caching, plus a small process supervisor, so a Heroku `web` dyno can run Caddy in front of an app on the same dyno.

Binary: Caddy v2.11.4 + `github.com/mholt/caddy-ratelimit` + `github.com/caddyserver/cache-handler` v0.17.0 + `github.com/darkweak/storages/otter/caddy` (in-memory cache storage).

## Usage

```bash
heroku buildpacks:add --index 1 https://github.com/CognyHub/caddy-edge-buildpack-heroku.git -a <app>
```

Add a `Caddyfile.template` at your repo root. Caddy must listen on `:{$PORT}` and proxy to your app on loopback. If you add none, a default that proxies to `127.0.0.1:3000` is used.

`Procfile`:

```
web: ./start_edge.sh <your app start command bound to 127.0.0.1:3000>
```

`start_edge.sh` runs your command and Caddy side by side. When either exits, it stops the other and exits with the same status, so Heroku restarts the dyno.

## Configuration

| Config var | Purpose |
|---|---|
| `CADDY_EDGE_VERSION` | Release tag to install (default: `VERSION` file) |
| `CADDY_EDGE_BASE_URL` | Download base URL override (tests) |

## Releasing a new binary

1. Edit pins in `xcaddy.sh`.
2. Commit, then `git tag vX.Y.Z && git push origin vX.Y.Z`. CI builds, verifies modules and publishes the Release.
3. Update `VERSION` to the new tag and commit.

## Tests

```bash
bash tests/start_edge_test.sh
bash tests/start_caddy_test.sh
bash tests/compile_test.sh
```

This repo must stay public: Heroku and `bin/compile` fetch it anonymously.
