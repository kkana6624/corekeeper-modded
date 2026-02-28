#!/usr/bin/env bash
set -euo pipefail

# discord.sh: Sends a message to the Discord Webhook defined in DISCORD_WEBHOOK_URL.
# Usage: 
#   ./discord.sh "Your message here"
#   ./discord.sh --json '{"content": "...", "embeds": [...]}'

if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  # No webhook configured, silent exit.
  exit 0
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed" >&2
    exit 1
fi

tmp_payload="/tmp/discord_payload_${RANDOM:-$$}.json"

# Argument parsing
if [[ "${1:-}" == "--json" ]]; then
    payload_data="${2:-}"
    if [[ -z "$payload_data" ]]; then
        echo "Usage: $0 --json <json_string>" >&2
        exit 1
    fi
    # Validate/Format JSON with jq
    if ! echo "$payload_data" | jq . > "$tmp_payload"; then
        echo "Error: Invalid JSON payload provided" >&2
        rm -f "$tmp_payload"
        exit 1
    fi
else
    message="${1:-}"
    if [[ -z "$message" ]]; then
        echo "Usage: $0 <message>" >&2
        exit 1
    fi
    
    # Construct JSON payload with safely escaped content
    # We use jq to handle the escaping mechanism.
    if ! jq -nc --arg content "$message" '{content: $content}' > "$tmp_payload"; then
        echo "Error: Failed to construct JSON payload" >&2
        rm -f "$tmp_payload"
        exit 1
    fi
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
