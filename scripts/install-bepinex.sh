#!/usr/bin/env bash
set -euo pipefail

: "${HOMEDIR:=/home/steam}"
: "${STEAMAPPDIR:=${HOMEDIR}/core-keeper-dedicated}"
: "${STEAMAPPDATADIR:=${HOMEDIR}/core-keeper-data}"

: "${BEPINEX_ENABLED:=false}"
: "${BEPINEX_RELEASE:=5.4.23.4}"
: "${BEPINEX_ZIP_URL:=}"

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

if [[ ! "${BEPINEX_ENABLED:-false}" =~ ^([Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])$ ]]; then
  exit 0
fi

cd "${STEAMAPPDIR}" || exit 1

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

zip_path="${tmpdir}/bepinex.zip"

if [[ -n "${BEPINEX_ZIP_URL}" ]]; then
  url_list=("${BEPINEX_ZIP_URL}")
else
  # Official docs: pick the build matching your OS/arch.
  # v5.4.23.2+ splits Unix builds into linux_x86/linux_x64/macos_x64.
  url_list=(
    # New naming (5.4.23.2+)
    "https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_RELEASE}/BepInEx_linux_x64_${BEPINEX_RELEASE}.zip"
    "https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_RELEASE}/BepInEx_linux_x64_${BEPINEX_RELEASE}.0.zip"
    "https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_RELEASE}/BepInEx_linux_x64_${BEPINEX_RELEASE}.1.zip"
    # Legacy naming (<=5.4.23.1 and some older versions)
    "https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_RELEASE}/BepInEx_unix_${BEPINEX_RELEASE}.zip"
    "https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_RELEASE}/BepInEx_unix_${BEPINEX_RELEASE}.0.zip"
    "https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_RELEASE}/BepInEx_unix_${BEPINEX_RELEASE}.1.zip"
  )
fi

downloaded=false
for url in "${url_list[@]}"; do
  log "Downloading BepInEx: ${url}"
  if curl -fsSL "$url" -o "$zip_path"; then
    downloaded=true
    break
  fi
done

if [[ "$downloaded" != true ]]; then
  err "Failed to download BepInEx. Set BEPINEX_ZIP_URL to a direct release asset URL."
  exit 1
fi

log "Extracting BepInEx into ${STEAMAPPDIR}"
unzip -q -o "$zip_path" -d "${STEAMAPPDIR}"

if [[ ! -f "${STEAMAPPDIR}/run_bepinex.sh" ]]; then
  err "run_bepinex.sh not found after extraction; check the archive and STEAMAPPDIR."
  exit 1
fi

# We don't rely on run_bepinex.sh for launching (we need to pass server args),
# but keep it executable for reference/debugging.
chmod u+x "${STEAMAPPDIR}/run_bepinex.sh" 2>/dev/null || true

# Persist mod configuration/state under server-data
# - Keep BepInEx core files in game root (ephemeral, updated by install)
# - Persist user-managed parts (plugins/config/patchers/log) under server-data
persistent_root="${STEAMAPPDATADIR}/bepinex"
mkdir -p "${persistent_root}/plugins" "${persistent_root}/config" "${persistent_root}/patchers"

mkdir -p "${STEAMAPPDIR}/BepInEx" || true

for d in plugins config patchers; do
  rm -rf "${STEAMAPPDIR}/BepInEx/${d}" || true
  ln -s "${persistent_root}/${d}" "${STEAMAPPDIR}/BepInEx/${d}"
done

# Persist BepInEx log file as well
touch "${persistent_root}/LogOutput.log"
rm -f "${STEAMAPPDIR}/BepInEx/LogOutput.log" || true
ln -s "${persistent_root}/LogOutput.log" "${STEAMAPPDIR}/BepInEx/LogOutput.log"

log "BepInEx install/update done"
