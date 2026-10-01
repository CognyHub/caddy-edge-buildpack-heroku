#!/usr/bin/env bash
# Tests for start_edge.sh using fake app/caddy processes.
# Each fake spawns a long-lived grandchild (sleep) and records its pid,
# so we can assert that nothing is orphaned.
set -uo pipefail
set -m # background jobs get their own process group, so `kill 0` inside start_edge.sh cannot hit this test

ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0

ok() { echo "ok   $1"; }
ko() { echo "FAIL $1"; fail=1; }

# setup <caddy_sleep_seconds> <caddy_exit_code>
setup() {
  W=$(mktemp -d)
  cp "$ROOT/start_edge.sh" "$W/"
  cat > "$W/start_caddy.sh" <<EOF
#!/usr/bin/env bash
sleep 60 &
echo \$! > "$W/caddy_grandchild.pid"
sleep $1
exit $2
EOF
  chmod +x "$W/start_edge.sh" "$W/start_caddy.sh"
}

# fake_app <sleep_seconds> <exit_code>  -> prints a command string for start_edge.sh
fake_app() {
  echo "sleep 60 & echo \$! > '$W/app_grandchild.pid'; sleep $1; exit $2"
}

# wait_exit <pid> <max_tenths>  -> sets EXIT_CODE, returns 1 on timeout
wait_exit() {
  local pid=$1 max=$2 i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -gt "$max" ]; then return 1; fi
    sleep 0.1
  done
  wait "$pid"
  EXIT_CODE=$?
  return 0
}

alive() { kill -0 "$(cat "$1")" 2>/dev/null; }

# Case 1: app exits 3 first -> start_edge exits 3, caddy side is gone
setup 60 0
(cd "$W" && exec ./start_edge.sh bash -c "$(fake_app 0.3 3)") &
pid=$!
if wait_exit "$pid" 30; then
  [ "$EXIT_CODE" -eq 3 ] && ok "app crash: exit code propagated" || ko "app crash: exit code $EXIT_CODE, want 3"
  sleep 0.2
  alive "$W/caddy_grandchild.pid" && ko "app crash: caddy grandchild orphaned" || ok "app crash: caddy grandchild killed"
  alive "$W/app_grandchild.pid" && ko "app crash: app grandchild orphaned" || ok "app crash: app grandchild killed"
else
  ko "app crash: start_edge did not exit within 3s"; kill -TERM -"$pid" 2>/dev/null
fi

# Case 2: caddy exits 5 first -> start_edge exits 5, app side is gone
setup 0.3 5
(cd "$W" && exec ./start_edge.sh bash -c "$(fake_app 60 0)") &
pid=$!
if wait_exit "$pid" 30; then
  [ "$EXIT_CODE" -eq 5 ] && ok "caddy crash: exit code propagated" || ko "caddy crash: exit code $EXIT_CODE, want 5"
  sleep 0.2
  alive "$W/app_grandchild.pid" && ko "caddy crash: app grandchild orphaned" || ok "caddy crash: app grandchild killed"
else
  ko "caddy crash: start_edge did not exit within 3s"; kill -TERM -"$pid" 2>/dev/null
fi

# Case 3: arguments with spaces are passed through intact
setup 60 0
(cd "$W" && exec ./start_edge.sh bash -c 'echo "$1" > out.txt; exit 7' _ "a b  c") &
pid=$!
if wait_exit "$pid" 30; then
  [ "$(cat "$W/out.txt")" = "a b  c" ] && ok "args: quoting preserved" || ko "args: got '$(cat "$W/out.txt")'"
else
  ko "args: start_edge did not exit"; kill -TERM -"$pid" 2>/dev/null
fi

exit $fail
