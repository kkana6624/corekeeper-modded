#!/usr/bin/env bash
set -euo pipefail

: "${HOMEDIR:=/home/steam}"
: "${STEAMAPPDIR:=${HOMEDIR}/core-keeper-dedicated}"
: "${STEAMAPPDATADIR:=${HOMEDIR}/core-keeper-data}"
: "${STEAMCMDDIR:=${HOMEDIR}/steamcmd}"
: "${SCRIPTSDIR:=${HOMEDIR}/scripts}"

: "${STEAMAPPID:=1007}"
: "${STEAMAPPID_TOOL:=1963720}"

mkdir -p "${STEAMAPPDIR}" "${STEAMAPPDATADIR}"

args=(
  "+@sSteamCmdForcePlatformType" "linux"
  "+@sSteamCmdForcePlatformBitness" "64"
  "+force_install_dir" "${STEAMAPPDIR}"
  "+login" "anonymous"
  "+app_update" "${STEAMAPPID}" "validate"
  "+app_update" "${STEAMAPPID_TOOL}" "validate"
)

# Optional: allow extra args for betas/testing
# If you want multiple tokens, pass as a single string and let bash split it.
if [[ -n "${STEAMCMD_UPDATE_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  extra=( ${STEAMCMD_UPDATE_ARGS} )
  args+=("${extra[@]}")
fi

args+=("+quit")

"${STEAMCMDDIR}/steamcmd.sh" "${args[@]}"

chmod +x "${STEAMAPPDIR}/CoreKeeperServer" || true

exec bash "${SCRIPTSDIR}/launch.sh"
