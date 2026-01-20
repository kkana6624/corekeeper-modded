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

# Force new Game ID generation if not manually specified AND explicitly requested
if [[ -z "${GAME_ID:-}" ]] && [[ "${DISCARD_GAME_ID:-false}" =~ ^([Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])$ ]]; then
  config_path="${DATA_PATH:-${STEAMAPPDATADIR}}/ServerConfig.json"
  if [[ -f "$config_path" ]]; then
    echo "Removing ${config_path} to force new Game ID generation..."
    rm "$config_path"
  fi
  # Also remove backup if it exists
  if [[ -f "${config_path}.pugbackup" ]]; then
    rm "${config_path}.pugbackup"
  fi
fi

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

# Stream logs to container stdout
# (Unity writes to logfile; tail makes it visible in docker logs)
tail --pid "$ckpid" -n +1 -f "$logfile" &

if [[ "${BEPINEX_ENABLED:-false}" =~ ^([Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])$ ]]; then
  # `tail -F` will retry until the file appears
  tail --pid "$ckpid" -n +1 -F "${STEAMAPPDIR}/BepInEx/LogOutput.log" &
fi

wait "$ckpid"
