#!/usr/bin/env bash
set -euo pipefail

: "${HOMEDIR:=/home/steam}"
: "${STEAMAPPDIR:=${HOMEDIR}/core-keeper-dedicated}"
: "${STEAMCMDDIR:=${HOMEDIR}/steamcmd}"
: "${STEAMAPPDATADIR:=${HOMEDIR}/core-keeper-data}"

cd "${STEAMAPPDIR}"

mkdir -p "${STEAMAPPDIR}/logs"
logfile="${STEAMAPPDIR}/logs/$(date '+%Y-%m-%d_%H-%M-%S').log"
touch "$logfile"

params=(
  "-batchmode"
  "-logfile" "$logfile"
)

add_param() {
  local key="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    params+=("$key" "$value")
  fi
}

add_param "-world" "${WORLD_INDEX:-0}"
add_param "-worldname" "${WORLD_NAME:-Core Keeper Server}"
add_param "-worldseed" "${WORLD_SEED:-}"
add_param "-worldmode" "${WORLD_MODE:-0}"
add_param "-gameid" "${GAME_ID:-}"
add_param "-datapath" "${DATA_PATH:-${STEAMAPPDATADIR}}"
add_param "-maxplayers" "${MAX_PLAYERS:-10}"
add_param "-ip" "${SERVER_IP:-}"
add_param "-port" "${SERVER_PORT:-}"
add_param "-password" "${PASSWORD:-}"

# Start a tiny X server for Unity headless
Xvfb :99 -screen 0 1x1x24 -nolisten tcp &
xvfbpid=$!

cleanup() {
  set +e
  if [[ -n "${ckpid:-}" ]]; then
    kill "$ckpid" 2>/dev/null || true
    wait "$ckpid" 2>/dev/null || true
  fi
  if [[ -n "${xvfbpid:-}" ]]; then
    kill "$xvfbpid" 2>/dev/null || true
    wait "$xvfbpid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

export DISPLAY=:99

# Ensure Steam runtime libs are visible
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:${STEAMCMDDIR}/linux64"

./CoreKeeperServer "${params[@]}" &
ckpid=$!

# Stream logs to container stdout
# (Unity writes to logfile; tail makes it visible in docker logs)
tail --pid "$ckpid" -n +1 -f "$logfile" &

wait "$ckpid"
