#!/usr/bin/env bash
set -euo pipefail

# player_monitor.sh: Monitors server log for player join/leave events and sends Discord notifications.
# Usage: ./player_monitor.sh <log_file_path>

LOG_FILE="${1:-}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$LOG_FILE" ]]; then
  echo "Usage: $0 <log_file_path>" >&2
  exit 1
fi

echo "Starting player monitor on: $LOG_FILE"

# Wait for log file to exist
while [[ ! -f "$LOG_FILE" ]]; do
  sleep 1
done

# Tail the log file and process lines
# Tail the log file and process lines
# Use an associative array to map UserID -> Name
declare -A players

tail -n0 -F "$LOG_FILE" | while read -r line; do
  # Pattern: [userid:2375247391] player ねこじた connected
  if [[ "$line" =~ \[userid:([0-9]+)\]\ player\ (.+)\ connected ]]; then
    uid="${BASH_REMATCH[1]}"
    name="${BASH_REMATCH[2]}"
    
    # Update cache
    players["$uid"]="$name"
    
    "${DIR}/discord.sh" "👋 **${name}** joined the server!"
    
  # Pattern: Disconnected from userid:2375247391
  elif [[ "$line" =~ Disconnected\ from\ userid:([0-9]+) ]]; then
    uid="${BASH_REMATCH[1]}"
    name="${players[$uid]:-}"
    
    if [[ -n "$name" ]]; then
      "${DIR}/discord.sh" "👋 **${name}** left the server"
      # Optional: Keep or clear name? Keeping it is safer for re-joins or rapid toggles.
    else
      "${DIR}/discord.sh" "👋 Player (ID: ${uid}) left the server"
    fi
  fi
done
