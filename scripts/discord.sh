#!/usr/bin/env bash
set -euo pipefail

# discord.sh: Sends a message to the Discord Webhook defined in DISCORD_WEBHOOK_URL.
# Usage: ./discord.sh "Your message here"

if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  # No webhook configured, silent exit.
  exit 0
fi

message="$1"
if [[ -z "$message" ]]; then
  echo "Usage: $0 <message>" >&2
  exit 1
fi

# Generate a temporary file path manually since mktemp can be unreliable in some environments or due to hooks
tmp_payload="/tmp/discord_payload_${RANDOM:-$$}.json"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed" >&2
    exit 1
fi

# Construct JSON payload
if ! jq -nc --arg content "$message" '{content: $content}' > "$tmp_payload"; then
    echo "Error: Failed to construct JSON payload" >&2
    rm -f "$tmp_payload"
    exit 1
fi

# Send to Discord
# -H: Content-Type
# -d: payload file
# -s: silent
# -S: show error on failure
# -f: fail silently (server-side errors)
curl -s -S -H "Content-Type: application/json" \
     -d @"$tmp_payload" \
     "${DISCORD_WEBHOOK_URL}" || echo "Warning: Failed to send valid Discord notification" >&2

rm -f "$tmp_payload"
