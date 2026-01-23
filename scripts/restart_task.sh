#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ------------------------------------------------------------------
# Restart Task Script
# Automates the daily restart process with Discord notifications.
# ------------------------------------------------------------------

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/core.env"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"
SERVICE_NAME="core-keeper" # Service name in compose.yml

# Load Environment Variables
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source <(sed -E 's/^([^=]+)=(.*)/\1="\2"/' "$ENV_FILE")
  set +a
fi

# Discord Helpers
notify_public() {
    local msg="$1"
    if [[ -f "${SCRIPT_DIR}/discord.sh" ]]; then
        bash "${SCRIPT_DIR}/discord.sh" "$msg"
    fi
}

notify_admin() {
    local msg="$1"
    local url="${DISCORD_MAINT_WEBHOOK_URL:-${DISCORD_WEBHOOK_URL:-}}"
    if [[ -n "$url" && -f "${SCRIPT_DIR}/discord.sh" ]]; then
        DISCORD_WEBHOOK_URL="$url" bash "${SCRIPT_DIR}/discord.sh" "$msg"
    fi
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "=== Scheduled Maintenance Sequence Initiated ==="

# === 0. Countdown ===
# Check if we should skip countdown (for testing)
if [[ "${SKIP_COUNTDOWN:-false}" != "true" ]]; then
    log "Countdown: 10 minutes"
    notify_public "📢 **Server Notification**\nServer maintenance will start in **10 minutes**.\nPlease prepare to log out."
    sleep 300

    log "Countdown: 5 minutes"
    notify_public "📢 **Server Notification**\nServer maintenance in **5 minutes**."
    sleep 240

    log "Countdown: 1 minute"
    notify_public "⚠️ **Warning**\nServer restarting in **1 minute**.\n**Please save and disconnect immediately.**"
    sleep 60
else
    log "Skipping countdown (SKIP_COUNTDOWN=true)"
fi

# === 1. Stop Server ===
log "Step 1: Stopping Server..."
notify_admin "🛠️ **Maintenance Started**\nStopping server process..."

if cd "$PROJECT_ROOT"; then
    if ! docker compose stop -t 60 "$SERVICE_NAME"; then
        log "Warning: Docker stop command failed or timed out."
        notify_admin "⚠️ **Warning:** Server stop command reported an error."
    else
        log "Server Stopped."
    fi
    sleep 5
else
    log "Error: Could not change directory to $PROJECT_ROOT"
    exit 1
fi

# === 2. Backup ===
log "Step 2: Starting Backup..."
backup_status=0
if [[ -f "$BACKUP_SCRIPT" ]]; then
    # backup.sh handles its own notifications (to maintenance channel) if successful/failed internally
    # But if the script itself crashes or exits non-zero, we catch it here.
    
    # Temporarily disable 'set -e' for the backup step so the whole script doesn't die
    set +e
    bash "$BACKUP_SCRIPT"
    backup_status=$?
    set -e
    
    if [[ $backup_status -ne 0 ]]; then
        log "⚠️ Backup script exited with error code: $backup_status"
        notify_admin "⚠️ **Error:** Backup process failed (Code: $backup_status). Proceeding to restart..."
    fi
else
    log "⚠️ Backup script not found: $BACKUP_SCRIPT"
    notify_admin "⚠️ **Error:** Backup script not found! Proceeding to restart..."
fi

# === 3. Start Server ===
log "Step 3: Starting Server..."
if docker compose up -d "$SERVICE_NAME"; then
    log "Server Start Command Sent."
else
    log "❌ Error: Failed to start server!"
    notify_admin "❌ **Critical Error:** Failed to start server container!"
    exit 1
fi

# === 4. Completion Notification ===
log "Maintenance sequence completed. Container startup will handle Game ID notification."
notify_public "✅ **Maintenance Complete**\nServer will be back online soon!"
notify_admin "✅ **Maintenance Complete** (Container restarted)"

log "=== Maintenance Sequence Finished ==="
