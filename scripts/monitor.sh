#!/usr/bin/env bash
set -euo pipefail
echo "Starting monitor.sh..."

: "${HOMEDIR:=/home/steam}"
: "${STEAMAPPDIR:=${HOMEDIR}/core-keeper-dedicated}"
: "${STEAMAPPDATADIR:=${HOMEDIR}/core-keeper-data}"
: "${SCRIPTSDIR:=${HOMEDIR}/scripts}"
: "${DATA_PATH:=${STEAMAPPDATADIR}}"

# Source discord helper
discord() {
  bash "${SCRIPTSDIR}/discord.sh" "$@"
}

log() { printf '%s\n' "$*"; }

# 1. Notify startup
discord "🚀 Core Keeper Server Starting..."

# 2. Monitor for Game ID
# The server writes to ServerConfig.json (or uses existing).
config_file="${DATA_PATH}/ServerConfig.json"

log "Waiting for Game ID in ${config_file}..."

max_retries=60 # Wait up to ~5 minutes (60 * 5s)
count=0

while [[ $count -lt $max_retries ]]; do
  # Check ServerConfig.json
  if [[ -f "$config_file" ]]; then
    if game_id=$(jq -r '.gameId // empty' "$config_file" 2>/dev/null); then
      if [[ -n "$game_id" && "$game_id" != "null" ]]; then
         log "Game ID found in ServerConfig.json: ${game_id}"
         discord "✅ Server Ready! Game ID: **\`${game_id}\`**"
         exit 0
      fi
    fi
  fi

  # Check GameID.txt (Standard dedicated server file)
  # Path based on logs: /home/steam/core-keeper-dedicated/GameID.txt
  gameid_txt="${STEAMAPPDIR}/GameID.txt"
  # log "Checking ${gameid_txt}" 
  if [[ -f "$gameid_txt" ]]; then
     game_id=$(cat "$gameid_txt")
     if [[ -n "$game_id" ]]; then
         log "Game ID found in GameID.txt: ${game_id}"
         discord "✅ Server Ready! Game ID: **\`${game_id}\`**"
         exit 0
     fi
  fi
  
  sleep 5
  count=$((count + 1))
done

log "Timed out waiting for Game ID."
discord "⚠️ Server started but Game ID could not be retrieved (Timeout)."
exit 0
