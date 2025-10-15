#!/bin/bash

# Deluge Post-Processing Script for Sonarr
# This script is called by Deluge's Execute plugin when a torrent completes
#
# Arguments from Deluge Execute plugin:
# $1 = Torrent ID
# $2 = Torrent Name
# $3 = Torrent Path

# Configuration
# Using IP addresses because Deluge shares Gluetun's network namespace
# IMPORTANT: Update these values with your actual Sonarr/Radarr IPs and API keys
SONARR_URL="http://172.20.0.3:8989/sonarr"  # Update with your Sonarr IP on vpn_network
SONARR_API_KEY="YOUR_SONARR_API_KEY_HERE"
RADARR_URL="http://172.20.0.2:7878/radarr"  # Update with your Radarr IP on vpn_network
RADARR_API_KEY="YOUR_RADARR_API_KEY_HERE"
LOG_FILE="/config/scripts/notify-sonarr.log"

# Get arguments
TORRENT_ID="$1"
TORRENT_NAME="$2"
TORRENT_PATH="$3"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================="
log "Torrent Completed: $TORRENT_NAME"
log "Torrent ID: $TORRENT_ID"
log "Torrent Path: $TORRENT_PATH"

# Wait a bit for Extractor plugin to finish if it's running
sleep 5

# Get torrent label using Deluge console (if available)
# This helps determine if it's a TV show or movie
LABEL=""
if command -v deluge-console &> /dev/null; then
    LABEL=$(deluge-console "info $TORRENT_ID" 2>/dev/null | grep -i "label:" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
    log "Torrent Label: ${LABEL:-none}"
fi

# Determine which service to notify based on label or path content
# TV shows typically have S##E## pattern, movies don't
if echo "$TORRENT_NAME" | grep -qiE 's[0-9]+e[0-9]+|season|episode'; then
    SERVICE="sonarr"
    API_URL="$SONARR_URL/api/v3/command"
    API_KEY="$SONARR_API_KEY"
    log "Detected: TV Show - notifying Sonarr"
elif [ "$LABEL" = "tv" ] || [ "$LABEL" = "sonarr" ]; then
    SERVICE="sonarr"
    API_URL="$SONARR_URL/api/v3/command"
    API_KEY="$SONARR_API_KEY"
    log "Label indicates TV Show - notifying Sonarr"
elif [ "$LABEL" = "movie" ] || [ "$LABEL" = "radarr" ] || [ "$LABEL" = "movies" ]; then
    SERVICE="radarr"
    API_URL="$RADARR_URL/api/v3/command"
    API_KEY="$RADARR_API_KEY"
    log "Label indicates Movie - notifying Radarr"
else
    # Default to trying both services
    log "Unable to determine content type, will try Sonarr first"
    SERVICE="sonarr"
    API_URL="$SONARR_URL/api/v3/command"
    API_KEY="$SONARR_API_KEY"
fi

# Call DownloadedEpisodesScan/DownloadedMoviesScan API
SCAN_COMMAND="DownloadedEpisodesScan"
if [ "$SERVICE" = "radarr" ]; then
    SCAN_COMMAND="DownloadedMoviesScan"
fi

log "Calling $SERVICE API: $SCAN_COMMAND"
log "Path: $TORRENT_PATH"

# Make the API call
RESPONSE=$(curl -s -X POST "$API_URL" \
    -H "X-Api-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$SCAN_COMMAND\", \"path\": \"$TORRENT_PATH\", \"importMode\": \"auto\"}")

# Check response
if echo "$RESPONSE" | grep -q '"id"'; then
    COMMAND_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    log "SUCCESS: $SERVICE import triggered (Command ID: $COMMAND_ID)"
else
    log "ERROR: Failed to trigger $SERVICE import"
    log "Response: $RESPONSE"

    # If Sonarr failed and we haven't tried Radarr yet, try Radarr
    if [ "$SERVICE" = "sonarr" ] && [ -z "$LABEL" ]; then
        log "Trying Radarr as fallback..."
        RESPONSE=$(curl -s -X POST "$RADARR_URL/api/v3/command" \
            -H "X-Api-Key: $RADARR_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"DownloadedMoviesScan\", \"path\": \"$TORRENT_PATH\", \"importMode\": \"auto\"}")

        if echo "$RESPONSE" | grep -q '"id"'; then
            COMMAND_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)
            log "SUCCESS: Radarr import triggered (Command ID: $COMMAND_ID)"
        else
            log "ERROR: Radarr import also failed"
            log "Response: $RESPONSE"
        fi
    fi
fi

log "Script completed"
log "========================================="

exit 0
