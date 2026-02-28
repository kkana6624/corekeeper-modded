#!/usr/bin/env bash
set -euo pipefail

# backup.sh: Archives server data and environment configuration to /data/backup
# and syncs to remote RPi using rsync.

# Determine project root (assuming script is in PROJECT_ROOT/scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
# Use process substitution with sed to double-quote values, avoiding issues with spaces.
# Use set -a to automatically export sourced variables so child scripts (discord.sh) can see them.
if [[ -f "$PROJECT_ROOT/core.env" ]]; then
  set -a
  source <(sed -e 's/[[:space:]]*#.*//' -e '/^\s*$/d' "$PROJECT_ROOT/core.env" | sed -E 's/^([^=]+)=(.*)/\1="\2"/')
  set +a
fi

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/data/backup"
ARCHIVE_NAME="backup_corekeeper_modded_$DATE.tar.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting backup..."
echo "Project Root: $PROJECT_ROOT"
echo "Backup File: $BACKUP_DIR/$ARCHIVE_NAME"

# 1. Create local backup
# Archive 'server-data' and 'core.env' if they exist
cd "$PROJECT_ROOT"
TARGETS=()
if [[ -f "core.env" ]]; then
  TARGETS+=("core.env")
fi
if [[ -d "server-data" ]]; then
  TARGETS+=("server-data")
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Error: No data found to backup." >&2
  exit 1
fi

tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" "${TARGETS[@]}"
echo "Local backup created."

# 2. Generation Management (Keep last 5)
cd "$BACKUP_DIR"
# Filter specifically for our modded backup naming pattern to avoid deleting other backups
ls -tp backup_corekeeper_modded_*.tar.gz | grep -v '/$' | tail -n +6 | xargs -r rm

# 3. Remote Sync (RPi)
SYNC_SUCCESS=false
if [[ -n "${RPI_USER:-}" ]] && [[ -n "${RPI_HOST:-}" ]] && [[ -n "${RPI_DEST_DIR:-}" ]]; then
  echo "Syncing to ${RPI_HOST}..."
  if rsync -avz -e "ssh -o StrictHostKeyChecking=no" "$BACKUP_DIR/$ARCHIVE_NAME" "${RPI_USER}@${RPI_HOST}:${RPI_DEST_DIR}/"; then
    SYNC_SUCCESS=true
    echo "Sync successful."
  else
    echo "Sync failed."
  fi
else
  echo "Skipping remote sync (RPI_USER/HOST/DEST_DIR not set)."
fi

# 4. Discord Notification
if [[ -n "${DISCORD_MAINT_WEBHOOK_URL:-}" ]]; then
    if [[ "$SYNC_SUCCESS" == "true" ]]; then
        MSG=$'📦 **Backup Successful (Modded)**\nSaved to local NVMe (/data/backup) and synced to RPi4.\nFile: \`'"$ARCHIVE_NAME"$'\`'
    else
        if [[ -n "${RPI_USER:-}" ]]; then
             MSG=$'⚠️ **Backup Warning (Modded)**\nLocal backup created, but **Transfer to RPi4 FAILED**.\nFile: \`'"$ARCHIVE_NAME"$'\`'
        else
             MSG=$'✅ **Backup Successful (Modded)**\nSaved to local NVMe (/data/backup). Remote sync skipped (not configured).\nFile: \`'"$ARCHIVE_NAME"$'\`'
        fi
    fi

    echo "Sending Discord notification..."
    
    # Use existing discord.sh if available, otherwise fallback to simple curl
    # Define the webhook URL to use for this specific call (override the default)
    if [[ -f "$SCRIPT_DIR/discord.sh" ]]; then
        DISCORD_WEBHOOK_URL="$DISCORD_MAINT_WEBHOOK_URL" "$SCRIPT_DIR/discord.sh" "$MSG"
    else
        # Fallback to curl if discord.sh is missing (simple JSON construction)
        curl -H "Content-Type: application/json" \
             -X POST \
             -d "{\"content\": \"$MSG\"}" \
             "$DISCORD_MAINT_WEBHOOK_URL"
    fi
fi

echo "Backup process completed."
