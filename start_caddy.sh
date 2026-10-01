#!/bin/sh

# format config
./caddy fmt --config "Caddyfile.template" --overwrite 
cp "Caddyfile.template" "Caddyfile"

# export config to json file
#./caddy adapt --config "Caddyfile" --adapter caddyfile --pretty > /tmp/config.json

# start process foreground
./caddy run --config "Caddyfile" --watch