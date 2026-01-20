#!/usr/bin/env bash
set -euo pipefail

# backup.sh: Archives server data and environment configuration.
# Usage: ./backup.sh [output_directory]

OUTPUT_DIR="${1:-backups}"
mkdir -p "$OUTPUT_DIR"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_FILE="${OUTPUT_DIR}/backup_corekeeper_${TIMESTAMP}.tar.gz"

echo "Starting backup to: ${BACKUP_FILE}"

# Files/Directories to backup
TARGETS=()

if [[ -f "core.env" ]]; then
  TARGETS+=("core.env")
fi
if [[ -d "server-data" ]]; then
  TARGETS+=("server-data")
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Error: No data found to backup (core.env or server-data)." >&2
  exit 1
fi

# Create archive
# We ignore "file changed as we read it" exit code (1) if using tar, but typical safe approach.
# Using tar -czf. 
tar -czf "$BACKUP_FILE" "${TARGETS[@]}"

echo "Backup created successfully: ${BACKUP_FILE}"
ls -lh "$BACKUP_FILE"
