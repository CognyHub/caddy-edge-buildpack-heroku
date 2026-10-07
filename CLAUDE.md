# CLAUDE.md — caddy-edge-buildpack-heroku

Heroku buildpack that installs a pinned Caddy binary with edge plugins (rate limit, cache) and a process supervisor.

## Layout

- `bin/compile` — downloads `caddy_linux_amd64` for the tag in `CADDY_EDGE_VERSION` or `VERSION`, verifies it against `SHA256SUMS` (fails the build on mismatch), caches it per tag, copies `start_caddy.sh` and `start_edge.sh`, and copies `Caddyfile.template` **only if the app has none**.
- `bin/detect` / `bin/release` — trivial.
- `start_caddy.sh` — `caddy fmt` the template, copy to `Caddyfile`, `caddy run`. No `--watch`: the file never changes on a running dyno (a config var change restarts it), and the watcher re-adapts the Caddyfile every second, repeating every adapter warning in the logs. Unlike `CognyHub/caddy-buildpack-heroku`, which still uses `--watch`.
- `start_edge.sh` — runs the app command and `start_caddy.sh`; when either exits, signals the whole process group and exits with that status.
- `xcaddy.sh` — the single source of Caddy and plugin version pins.
- `.github/workflows/release.yml` — on tag `v*`, builds linux/amd64 + darwin/arm64, checks the modules `http.handlers.rate_limit`, `http.handlers.cache`, `storages.cache.otter` and `storages.cache.simplefs`, and publishes a Release with `SHA256SUMS`.

## Rules

- Scripts must work on macOS `/bin/bash` 3.2 and heroku-24 bash 5 (no `wait -n`).
- Never commit binaries; they live in GitHub Releases.
- The repo must stay public.
- Run `bash tests/start_edge_test.sh && bash tests/start_caddy_test.sh && bash tests/compile_test.sh` before pushing.

## Consumers

- `CognyHub/produto-cogny` (app `gre-site-dev-2`).
