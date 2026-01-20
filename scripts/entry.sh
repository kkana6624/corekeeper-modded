#!/usr/bin/env bash
set -euo pipefail

# Minimal init:
# - if running as root, optionally remap steam uid/gid to match host
# - ensure mounted dirs are writable
# - exec setup as steam user

: "${HOMEDIR:=/home/steam}"
: "${USER:=steam}"
: "${STEAMAPPDIR:=${HOMEDIR}/core-keeper-dedicated}"
: "${STEAMAPPDATADIR:=${HOMEDIR}/core-keeper-data}"
: "${SCRIPTSDIR:=${HOMEDIR}/scripts}"

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

if [[ "$(id -u)" -eq 0 ]]; then
  if [[ "${PUID:-1000}" -eq 0 || "${PGID:-1000}" -eq 0 ]]; then
    err "PUID/PGID must be non-zero when running as root (set PUID/PGID)."
    exit 1
  fi

  log "Remapping steam user to ${PUID}:${PGID} (if needed)"
  usermod -o -u "${PUID}" "${USER}" >/dev/null 2>&1 || true
  groupmod -o -g "${PGID}" "${USER}" >/dev/null 2>&1 || true
  chown -R "${USER}:${USER}" "${HOMEDIR}" || true

  if [[ ! -w "${STEAMAPPDIR}" ]]; then
    err "${STEAMAPPDIR} is not writable"
    exit 1
  fi
  if [[ ! -w "${STEAMAPPDATADIR}" ]]; then
    err "${STEAMAPPDATADIR} is not writable"
    exit 1
  fi

  # Cleanup potential stale lock
  rm -f /tmp/.X99-lock || true

  exec gosu "${USER}" bash "${SCRIPTSDIR}/setup.sh"
else
  rm -f /tmp/.X99-lock || true
  exec bash "${SCRIPTSDIR}/setup.sh"
fi
