#!/bin/bash

set -euo pipefail

# Health check for Immich service
SERVER_URL="http://localhost:2283"

# Check if the server is responding
if curl -f -s "$SERVER_URL/api/server-info/ping" > /dev/null 2>&1; then
    echo '{"status": "running", "message": "Immich server is responding"}'
    exit 0
else
    echo '{"status": "error", "message": "Immich server is not responding"}'
    exit 1
fi