#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# Restart Task Script
# Automates the daily restart process with Discord notifications.
# ------------------------------------------------------------------

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/core.env"
COMPOSE_FILE="${PROJECT_ROOT}/compose.yml"
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
    if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
        curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$msg\"}" "$DISCORD_WEBHOOK_URL" || true
    fi
}

notify_admin() {
    local msg="$1"
    # Use Maintenance URL if set, otherwise fallback to Public URL
    local url="${DISCORD_MAINT_WEBHOOK_URL:-${DISCORD_WEBHOOK_URL:-}}"
    if [[ -n "$url" ]]; then
        curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$msg\"}" "$url" || true
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
    docker compose stop -t 60 "$SERVICE_NAME"
    log "Server Stopped."
    sleep 5
else
    log "Error: Could not change directory to $PROJECT_ROOT"
    exit 1
fi

# === 2. Backup ===
log "Step 2: Starting Backup..."
if [[ -f "$BACKUP_SCRIPT" ]]; then
    # backup.sh handles its own notifications (to maintenance channel)
    # We execute it in the current shell context or new one
    bash "$BACKUP_SCRIPT"
else
    log "⚠️ Backup script not found: $BACKUP_SCRIPT"
    notify_admin "⚠️ **Error:** Backup script not found!"
fi

# === 3. Start Server ===
log "Step 3: Starting Server..."
docker compose up -d "$SERVICE_NAME"
log "Server Start Command Sent."

# === 4. Completion Notification ===
log "Maintenance sequence completed. Container startup will handle Game ID notification."
notify_public "✅ **Maintenance Complete**\nServer will be back online soon!"
notify_admin "✅ **Maintenance Complete** (Container restarted)"

log "=== Maintenance Sequence Finished ==="
