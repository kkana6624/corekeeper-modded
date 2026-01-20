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
gameid_txt="${STEAMAPPDIR}/GameID.txt" # Standard dedicated server file

log "Waiting for Game ID in ${config_file} or ${gameid_txt}..."

# Game ID detection loop (simplified)
game_id=""
while [[ -z "$game_id" && "$count" -lt "$max_retries" ]]; do
  # Try to read from ServerConfig.json
  if [[ -f "$config_file" ]]; then
      if temp_game_id=$(jq -r '.gameId // empty' "$config_file" 2>/dev/null); then
          if [[ -n "$temp_game_id" && "$temp_game_id" != "null" ]]; then
              game_id="$temp_game_id"
              log "Game ID found in ServerConfig.json: $game_id"
              break
          fi
      fi
  fi
  
  # Fallback to GameID.txt
  if [[ -f "$gameid_txt" ]]; then
      temp_game_id=$(cat "$gameid_txt")
      if [[ -n "$temp_game_id" ]]; then
          game_id="$temp_game_id"
          log "Game ID found in GameID.txt: $game_id"
          break
      fi
  fi
  
  sleep 2
  count=$((count + 1))
done

if [[ -n "$game_id" ]]; then
  discord "✅ Server Ready! Game ID: \`${game_id}\`"
  exit 0
else
  log "Timed out waiting for Game ID."
  discord "⚠️ Server started but Game ID could not be retrieved (Timeout)."
  exit 0
fi
