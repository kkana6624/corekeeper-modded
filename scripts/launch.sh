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

# ==============================================================================
# Configuration Management & Dynamic Game ID
# ==============================================================================

config_path="${DATA_PATH:-${STEAMAPPDATADIR}}/ServerConfig.json"

# 1. Update/Create ServerConfig.json based on core.env (Source of Truth)
# We use jq to merge env vars into the config file.
# Priority: core.env > Existing Config > Defaults

# Ensure config file exists with empty json if missing
if [[ ! -f "$config_path" ]]; then
  echo "{}" > "$config_path"
fi

# Prepare values for jq (defaults if not set)
# Note: jq arg parsing handles empty strings gracefully usually, but we want explicit nulls or values.

# Helper to update a json field if env var is set
update_config() {
  local key="$1"
  local env_val="$2"
  local type="$3" # string or number

  if [[ -n "$env_val" ]]; then
    tmp=$(mktemp)
    if [[ "$type" == "number" ]]; then
       jq --argjson val "$env_val" ".$key = \$val" "$config_path" > "$tmp" && mv "$tmp" "$config_path"
    else
       jq --arg val "$env_val" ".$key = \$val" "$config_path" > "$tmp" && mv "$tmp" "$config_path"
    fi
  fi
}

echo "Updating ServerConfig.json from environment variables..."

# Standard settings
# Note: We do NOT update worldName here to respect priority (Env > Config > Default) without overwriting config.
# update_config "worldName" "${WORLD_NAME:-}" "string"
update_config "worldSeed" "${WORLD_SEED:-}" "string"
update_config "maxNumberPlayers" "${MAX_PLAYERS:-}" "number"
update_config "worldMode" "${WORLD_MODE:-}" "number"

# Extended settings requested by user
update_config "seasonOverride" "${SEASON_OVERRIDE:-}" "number"
update_config "networkSendRate" "${NETWORK_SEND_RATE:-}" "number"
update_config "maxNumberPacketsSentPerFrame" "${MAX_PACKETS:-}" "number"


# 2. Dynamic Game ID Logic
# If DISCARD_GAME_ID is set, we delete the `gameId` field from json and the text file.
if [[ "${DISCARD_GAME_ID:-false}" =~ ^([Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])$ ]]; then
  echo "Forcing new Game ID generation (DISCARD_GAME_ID=true)..."
  
  # Remove gameId from json
  tmp=$(mktemp)
  jq 'del(.gameId)' "$config_path" > "$tmp" && mv "$tmp" "$config_path"

  # Remove GameID.txt
  gameid_txt="${STEAMAPPDIR}/GameID.txt"
  if [[ -f "$gameid_txt" ]]; then
    rm "$gameid_txt"
  fi
  
  # Clean backups
  if [[ -f "${config_path}.pugbackup" ]]; then
    rm "${config_path}.pugbackup"
  fi
fi

# ==============================================================================

# Read final values from config to pass as arguments (for logging/consistency)
# Note: The server reads the JSON file, but passing args is good practice for some overrides.
# We will use the values potentially just updated.

c_worldName=$(jq -r '.worldName // empty' "$config_path")
c_worldSeed=$(jq -r '.worldSeed // empty' "$config_path")
c_maxPlayers=$(jq -r '.maxNumberPlayers // empty' "$config_path")
c_worldMode=$(jq -r '.worldMode // empty' "$config_path")
c_gameId=$(jq -r '.gameId // empty' "$config_path")

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

# Use the values we read back from the config (or defaults if they were missing in both env and json)
add_param "-world" "${WORLD_INDEX:-0}"
# Resolve World Name Priority:
# 1. Environment Variable ($WORLD_NAME)
# 2. ServerConfig.json Value ($c_worldName)
# 3. Default ("Core Keeper Server")
final_worldName="${WORLD_NAME:-${c_worldName:-Core Keeper Server}}"

add_param "-worldname" "${final_worldName}"
add_param "-worldseed" "${c_worldSeed:-}"
add_param "-worldmode" "${c_worldMode:-0}"
add_param "-gameid" "${c_gameId:-}"
add_param "-datapath" "${DATA_PATH:-${STEAMAPPDATADIR}}"
add_param "-maxplayers" "${c_maxPlayers:-10}"
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
  if [[ -n "${pmonpid:-}" ]]; then
    echo "Stopping player monitor..."
    kill "$pmonpid" 2>/dev/null || true
  fi
  LD_PRELOAD= bash "${SCRIPTSDIR}/discord.sh" "🛑 Server Stopped"
}
trap cleanup EXIT

export DISPLAY=:99

# Ensure Steam runtime libs are visible
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:${STEAMCMDDIR}/linux64"

if [[ "${BEPINEX_ENABLED:-false}" =~ ^([Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])$ ]]; then
  # Do NOT use BepInEx's run_bepinex.sh here:
  # - it treats $1 as an executable path and does not forward server args
  # - it relies on `file(1)` which isn't guaranteed to exist
  # Instead, configure Doorstop like the script does and run the server normally.
  arch=""
  case "$(uname -m)" in
    x86_64|amd64) arch="x64" ;;
    i386|i686) arch="x86" ;;
    *)
      echo "Unsupported architecture for BepInEx 5 unix build: $(uname -m)" >&2
      exit 1
      ;;
  esac

  # Doorstop env vars:
  # - Doorstop 4.x (BepInEx 5.4.23.2+) uses DOORSTOP_ENABLED/DOORSTOP_TARGET_ASSEMBLY.
  # - Older BepInEx unix zips used DOORSTOP_ENABLE/DOORSTOP_INVOKE_DLL_PATH.
  # Set both for compatibility.
  export DOORSTOP_ENABLED=1
  export DOORSTOP_TARGET_ASSEMBLY="${STEAMAPPDIR}/BepInEx/core/BepInEx.Preloader.dll"
  # Prefer BepInEx-bundled dependencies (HarmonyX/MonoMod/Mono.Cecil) over any game-bundled ones.
  # This avoids version-mismatch crashes like:
  #   MissingMethodException: ... MonoMod.Utils.DynamicMethodDefinition.get_Definition()
  export DOORSTOP_MONO_DLL_SEARCH_PATH_OVERRIDE="${STEAMAPPDIR}/BepInEx/core"

  export DOORSTOP_ENABLE=TRUE
  export DOORSTOP_INVOKE_DLL_PATH="${STEAMAPPDIR}/BepInEx/core/BepInEx.Preloader.dll"

  # Doorstop library location differs by distribution:
  # - Newer linux_x64 zips ship a single "libdoorstop.so" in the game root.
  # - Older unix zips used "doorstop_libs/libdoorstop_x64.so".
  doorstop_preload=""
  if [[ -f "${STEAMAPPDIR}/libdoorstop.so" ]]; then
    doorstop_preload="${STEAMAPPDIR}/libdoorstop.so"
  else
    doorstop_libs="${STEAMAPPDIR}/doorstop_libs"
    doorstop_libname="libdoorstop_${arch}.so"
    if [[ -f "${doorstop_libs}/${doorstop_libname}" ]]; then
      doorstop_preload="${doorstop_libs}/${doorstop_libname}"
      export LD_LIBRARY_PATH="${doorstop_libs}:${LD_LIBRARY_PATH}"
    fi
  fi

  if [[ -z "${doorstop_preload}" ]]; then
    echo "Doorstop preload library not found under ${STEAMAPPDIR} (expected libdoorstop.so or doorstop_libs/libdoorstop_${arch}.so)" >&2
    exit 1
  fi

  export LD_PRELOAD="${doorstop_preload}:${LD_PRELOAD:-}"
fi

./CoreKeeperServer "${params[@]}" &
ckpid=$!

# Start background monitor for Game ID
LD_PRELOAD= bash "${SCRIPTSDIR}/monitor.sh" &

# Start background player monitor (stateless log watcher)
LD_PRELOAD= bash "${SCRIPTSDIR}/player_monitor.sh" "$logfile" &
pmonpid=$!

# Stream logs to container stdout
# (Unity writes to logfile; tail makes it visible in docker logs)
tail --pid "$ckpid" -n +1 -f "$logfile" &

if [[ "${BEPINEX_ENABLED:-false}" =~ ^([Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])$ ]]; then
  # `tail -F` will retry until the file appears
  tail --pid "$ckpid" -n +1 -F "${STEAMAPPDIR}/BepInEx/LogOutput.log" &
fi

wait "$ckpid"
