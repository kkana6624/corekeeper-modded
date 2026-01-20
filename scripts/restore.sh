#!/usr/bin/env bash
set -euo pipefail

# restore.sh: Restores server data from a backup archive.
# Usage: ./restore.sh <path_to_archive.tar.gz>

ARCHIVE_PATH="${1:-}"
SERVER_DATA_DIR="./server-data"

if [[ -z "$ARCHIVE_PATH" ]]; then
  echo "Usage: $0 <path_to_archive.tar.gz>" >&2
  exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Error: Archive file not found: $ARCHIVE_PATH" >&2
  exit 1
fi

if [[ ! -d "$SERVER_DATA_DIR" ]]; then
  echo "Warning: ${SERVER_DATA_DIR} does not exist. Creating it..."
  mkdir -p "$SERVER_DATA_DIR"
fi

# Check if container is running
if docker compose ps --services --filter "status=running" 2>/dev/null | grep -q "core-keeper-dedicated"; then
  echo "❌ ERROR: The 'core-keeper-dedicated' container is currently RUNNING."
  echo "Please stop the server before restoring a backup to prevent data corruption."
  echo "Run: docker compose stop"
  exit 1
fi

echo "=================================================="
echo "⚠️  WARNING: SERVER RESTORATION ⚠️"
echo "=================================================="
echo "Target: ${SERVER_DATA_DIR}"
echo "Source: ${ARCHIVE_PATH}"
echo ""
echo "This will OVERWRITE existing files that exist in the backup."
echo "However, folders NOT in the backup (like 'bepinex/') will be PRESERVED."
echo "Please ensure the server (Docker container) is STOPPED before proceeding."
echo ""
# Check if archive contains core.env
has_env=false
if tar -tf "$ARCHIVE_PATH" | grep "core.env" > /dev/null; then
  has_env=true
  echo "⚠️  This backup contains 'core.env'."
  echo "    Restoring it will OVERWRITE your current configuration."
fi

read -rp "Are you sure you want to continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Restoration cancelled."
  exit 0
fi

echo "Restoring..."

# 1. Restore core.env if present
if [[ "$has_env" == true ]]; then
  echo "Restoring core.env..."
  tar -xzf "$ARCHIVE_PATH" core.env
fi

# 2. Restore server-data
# Detect directory structure in archive to determine strip components
# We look for 'ServerConfig.json' to gauge the depth
config_path=$(tar -tf "$ARCHIVE_PATH" | grep "ServerConfig.json" | head -n 1)

if [[ -z "$config_path" ]]; then
  echo "Warning: ServerConfig.json not found in backup. Assuming 0 strip components."
  strip_count=0
else
  # Count occurrences of '/'
  slash_count=$(echo "$config_path" | tr -cd '/' | wc -c)
  strip_count=$slash_count
fi

echo "Restoring server-data..."

if [[ "$has_env" == "true" ]]; then
  # New backup format (root is 'server-data')
  tar -xzf "$ARCHIVE_PATH" server-data
else
  # Legacy backup format (root is 'data' or similar)
  echo "  Stripping $strip_count leading components..."
  tar -xzf "$ARCHIVE_PATH" -C "$SERVER_DATA_DIR" --strip-components="$strip_count"
fi

echo "Restoration complete."
echo "Please check '${SERVER_DATA_DIR}' content before starting the server."
