set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0

ok() { echo "ok   $1"; }
ko() { echo "FAIL $1"; fail=1; }

W=$(mktemp -d)
cp "$ROOT/start_caddy.sh" "$W/"
printf 'localhost:{$PORT}\nrespond "hi"\n' > "$W/Caddyfile.template"
cat > "$W/caddy" <<FAKE
#!/bin/sh
echo "\$*" >> "$W/caddy_calls"
FAKE
chmod +x "$W/caddy" "$W/start_caddy.sh"

(cd "$W" && ./start_caddy.sh)

run=$(grep '^run ' "$W/caddy_calls")
[ "$run" = "run --config Caddyfile" ] && ok "caddy run without --watch" || ko "caddy run got '$run'"
[ -f "$W/Caddyfile" ] && ok "Caddyfile copied from template" || ko "Caddyfile missing"

exit $fail
