#!/usr/bin/env bash
# Usage: ./start_edge.sh <app command...>
# Runs the app and Caddy; when either exits, stops the other and exits
# with the same status so Heroku restarts the dyno.
"$@" &
app=$!
./start_caddy.sh &
caddy=$!
while kill -0 "$app" 2>/dev/null && kill -0 "$caddy" 2>/dev/null; do
  sleep 0.5
done
if kill -0 "$app" 2>/dev/null; then wait "$caddy"; else wait "$app"; fi
status=$?
trap '' TERM
kill -TERM 0 2>/dev/null
wait
exit "$status"
