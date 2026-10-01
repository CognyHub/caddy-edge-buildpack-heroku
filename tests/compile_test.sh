#!/usr/bin/env bash
# Tests bin/compile against a local file:// fixture release.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0
ok() { echo "ok   $1"; }
ko() { echo "FAIL $1"; fail=1; }
sha() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'; }

# fixture <dir> <version> <good|bad>
fixture() {
  mkdir -p "$1/$2"
  printf '#!/bin/sh\necho fake-caddy\n' > "$1/$2/caddy_linux_amd64"
  if [ "$3" = good ]; then h=$(sha "$1/$2/caddy_linux_amd64"); else h=0000000000000000000000000000000000000000000000000000000000000000; fi
  printf '%s  caddy_linux_amd64\n' "$h" > "$1/$2/SHA256SUMS"
}

T=$(mktemp -d)
fixture "$T/rel" v-test good
fixture "$T/rel" v-bad bad
export CADDY_EDGE_BASE_URL="file://$T/rel"

# 1. App without its own template -> default copied, scripts + binary installed
B=$T/b1; C=$T/c1; mkdir -p "$B" "$C"
if CADDY_EDGE_VERSION=v-test "$ROOT/bin/compile" "$B" "$C" > "$T/out1" 2>&1; then
  [ -x "$B/caddy" ] && [ "$("$B/caddy")" = fake-caddy ] && ok "binary installed" || ko "binary missing/not executable"
  [ -x "$B/start_caddy.sh" ] && [ -x "$B/start_edge.sh" ] && ok "scripts installed" || ko "scripts missing"
  cmp -s "$B/Caddyfile.template" "$ROOT/Caddyfile.template" && ok "default template copied" || ko "default template not copied"
  grep -q "default Caddyfile.template" "$T/out1" && ok "logs default template" || ko "no default-template log line"
else
  ko "compile failed: $(cat "$T/out1")"
fi

# 2. App template is preserved
B=$T/b2; C=$T/c2; mkdir -p "$B" "$C"; echo "APP-OWNED" > "$B/Caddyfile.template"
CADDY_EDGE_VERSION=v-test "$ROOT/bin/compile" "$B" "$C" > "$T/out2" 2>&1
[ "$(cat "$B/Caddyfile.template")" = APP-OWNED ] && ok "app template preserved" || ko "app template overwritten"
grep -q "app Caddyfile.template" "$T/out2" && ok "logs app template" || ko "no app-template log line"

# 3. Checksum mismatch fails the build and installs nothing
B=$T/b3; C=$T/c3; mkdir -p "$B" "$C"
if CADDY_EDGE_VERSION=v-bad "$ROOT/bin/compile" "$B" "$C" > "$T/out3" 2>&1; then
  ko "bad checksum accepted"
else
  ok "bad checksum rejected"
fi
[ ! -e "$B/caddy" ] && ok "no binary after bad checksum" || ko "binary installed despite bad checksum"
[ ! -e "$C/caddy-edge/v-bad/caddy_linux_amd64" ] && ok "bad binary not cached" || ko "bad binary cached"

# 4. Second build reuses the cache (fixture removed)
B=$T/b4; mkdir -p "$B"
mv "$T/rel/v-test" "$T/rel/v-test.off"
CADDY_EDGE_VERSION=v-test "$ROOT/bin/compile" "$B" "$T/c1" > "$T/out4" 2>&1 && [ -x "$B/caddy" ] && ok "cache reused offline" || ko "cache not reused: $(cat "$T/out4")"
mv "$T/rel/v-test.off" "$T/rel/v-test"

# 5. Version read from Heroku env-dir file when not in environment
B=$T/b5; C=$T/c5; E=$T/e5; mkdir -p "$B" "$C" "$E"; printf 'v-test' > "$E/CADDY_EDGE_VERSION"
env -u CADDY_EDGE_VERSION "$ROOT/bin/compile" "$B" "$C" "$E" > "$T/out5" 2>&1 && grep -q "Caddy Edge v-test" "$T/out5" && ok "version from env-dir" || ko "env-dir version ignored: $(cat "$T/out5")"

# 6. Missing release fails
B=$T/b6; C=$T/c6; mkdir -p "$B" "$C"
CADDY_EDGE_VERSION=v-nope "$ROOT/bin/compile" "$B" "$C" > "$T/out6" 2>&1 && ko "missing release accepted" || ok "missing release rejected"

exit $fail
