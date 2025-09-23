#!/bin/bash

# Automated Service Configuration Script
# Applies API keys and configures service connections

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load secrets
source /docker/mediaserver/.env.secrets

echo "========================================="
echo "Automated Service Configuration"
echo "========================================="
echo ""

# Function to configure download client in arr service
configure_download_client() {
    local service=$1
    local service_url=$2
    local api_key=$3

    echo -e "${BLUE}Configuring download clients for $service...${NC}"

    # Configure SABnzbd
    echo -n "  Adding SABnzbd... "
    curl -s -X POST "$service_url/api/v3/downloadclient" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
            "enable": true,
            "protocol": "usenet",
            "priority": 1,
            "removeCompletedDownloads": true,
            "removeFailedDownloads": true,
            "name": "SABnzbd",
            "fields": [
                {"name": "host", "value": "gluetun"},
                {"name": "port", "value": 8080},
                {"name": "apiKey", "value": "'$SABNZBD_API_KEY'"},
                {"name": "tvCategory", "value": "tv"},
                {"name": "movieCategory", "value": "movies"},
                {"name": "useSsl", "value": false}
            ],
            "implementationName": "SABnzbd",
            "implementation": "Sabnzbd",
            "configContract": "SabnzbdSettings",
            "infoLink": "https://wiki.servarr.com/sonarr/supported#sabnzbd",
            "tags": []
        }' 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}Already exists or failed${NC}"

    # Configure Deluge
    echo -n "  Adding Deluge... "
    curl -s -X POST "$service_url/api/v3/downloadclient" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
            "enable": true,
            "protocol": "torrent",
            "priority": 2,
            "removeCompletedDownloads": true,
            "removeFailedDownloads": true,
            "name": "Deluge (VPN)",
            "fields": [
                {"name": "host", "value": "gluetun"},
                {"name": "port", "value": 8112},
                {"name": "password", "value": "'$DELUGE_PASSWORD'"},
                {"name": "tvCategory", "value": "tv"},
                {"name": "movieCategory", "value": "movies"},
                {"name": "useSsl", "value": false}
            ],
            "implementationName": "Deluge",
            "implementation": "Deluge",
            "configContract": "DelugeSettings",
            "infoLink": "https://wiki.servarr.com/sonarr/supported#deluge",
            "tags": []
        }' 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}Already exists or failed${NC}"
}

# Configure Prowlarr apps
configure_prowlarr_apps() {
    echo -e "${BLUE}Configuring Prowlarr application connections...${NC}"

    # Add Sonarr to Prowlarr
    echo -n "  Adding Sonarr... "
    curl -s -X POST "http://prowlarr:9696/api/v1/applications" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Sonarr",
            "syncLevel": "fullSync",
            "fields": [
                {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
                {"name": "baseUrl", "value": "http://sonarr:8989"},
                {"name": "apiKey", "value": "'$SONARR_API_KEY'"},
                {"name": "syncCategories", "value": [5000, 5010, 5020, 5030, 5040, 5045, 5050]}
            ],
            "implementationName": "Sonarr",
            "implementation": "Sonarr",
            "configContract": "SonarrSettings",
            "tags": []
        }' 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}Already exists or failed${NC}"

    # Add Radarr to Prowlarr
    echo -n "  Adding Radarr... "
    curl -s -X POST "http://prowlarr:9696/api/v1/applications" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Radarr",
            "syncLevel": "fullSync",
            "fields": [
                {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
                {"name": "baseUrl", "value": "http://radarr:7878"},
                {"name": "apiKey", "value": "'$RADARR_API_KEY'"},
                {"name": "syncCategories", "value": [2000, 2010, 2020, 2030, 2040, 2045, 2050]}
            ],
            "implementationName": "Radarr",
            "implementation": "Radarr",
            "configContract": "RadarrSettings",
            "tags": []
        }' 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}Already exists or failed${NC}"

    # Add Lidarr to Prowlarr
    echo -n "  Adding Lidarr... "
    curl -s -X POST "http://prowlarr:9696/api/v1/applications" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Lidarr",
            "syncLevel": "fullSync",
            "fields": [
                {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
                {"name": "baseUrl", "value": "http://lidarr:8686"},
                {"name": "apiKey", "value": "'$LIDARR_API_KEY'"},
                {"name": "syncCategories", "value": [3000, 3010, 3020, 3030, 3040]}
            ],
            "implementationName": "Lidarr",
            "implementation": "Lidarr",
            "configContract": "LidarrSettings",
            "tags": []
        }' 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}Already exists or failed${NC}"

    # Add Readarr to Prowlarr
    echo -n "  Adding Readarr... "
    curl -s -X POST "http://prowlarr:9696/api/v1/applications" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Readarr",
            "syncLevel": "fullSync",
            "fields": [
                {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
                {"name": "baseUrl", "value": "http://readarr:8787"},
                {"name": "apiKey", "value": "'$READARR_API_KEY'"},
                {"name": "syncCategories", "value": [7000, 7020]}
            ],
            "implementationName": "Readarr",
            "implementation": "Readarr",
            "configContract": "ReadarrSettings",
            "tags": []
        }' 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}Already exists or failed${NC}"
}

# Wait for services to be ready
echo -e "${BLUE}Checking service availability...${NC}"
services=(
    "sonarr:8989"
    "radarr:7878"
    "lidarr:8686"
    "readarr:8787"
    "prowlarr:9696"
)

for service_port in "${services[@]}"; do
    IFS=':' read -r service port <<< "$service_port"
    echo -n "  Checking $service... "
    timeout 30 bash -c "until curl -s http://$service:$port/ping >/dev/null 2>&1; do sleep 1; done"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Not responding${NC}"
    fi
done

echo ""

# Configure download clients
echo -e "${YELLOW}Step 1: Configuring Download Clients${NC}"
echo "-------------------------------------"
configure_download_client "Sonarr" "http://sonarr:8989" "$SONARR_API_KEY"
configure_download_client "Radarr" "http://radarr:7878" "$RADARR_API_KEY"
echo ""

# Configure Prowlarr
echo -e "${YELLOW}Step 2: Configuring Prowlarr Applications${NC}"
echo "-----------------------------------------"
configure_prowlarr_apps
echo ""

# Test configurations
echo -e "${YELLOW}Step 3: Testing Configurations${NC}"
echo "------------------------------"

# Test Sonarr
echo -n "  Testing Sonarr download clients... "
result=$(curl -s "http://sonarr:8989/api/v3/downloadclient" -H "X-Api-Key: $SONARR_API_KEY" | grep -c "SABnzbd")
if [ "$result" -gt 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Test Radarr
echo -n "  Testing Radarr download clients... "
result=$(curl -s "http://radarr:7878/api/v3/downloadclient" -H "X-Api-Key: $RADARR_API_KEY" | grep -c "SABnzbd")
if [ "$result" -gt 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Test Prowlarr
echo -n "  Testing Prowlarr applications... "
result=$(curl -s "http://prowlarr:9696/api/v1/applications" -H "X-Api-Key: $PROWLARR_API_KEY" | grep -c "Sonarr")
if [ "$result" -gt 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Configuration Summary${NC}"
echo "----------------------------"
cat << EOF

Services configured with API keys:
- Sonarr: ${SONARR_API_KEY:0:8}...
- Radarr: ${RADARR_API_KEY:0:8}...
- Lidarr: ${LIDARR_API_KEY:0:8}...
- Readarr: ${READARR_API_KEY:0:8}...
- Prowlarr: ${PROWLARR_API_KEY:0:8}...
- SABnzbd: ${SABNZBD_API_KEY:0:8}...

Download Clients configured in:
- Sonarr: SABnzbd (gluetun:8080), Deluge (gluetun:8112)
- Radarr: SABnzbd (gluetun:8080), Deluge (gluetun:8112)

Prowlarr connected to:
- Sonarr, Radarr, Lidarr, Readarr

EOF

echo -e "${BLUE}Next Manual Steps:${NC}"
echo "1. Add indexers in Prowlarr web UI (http://192.168.1.100:80/prowlarr)"
echo "2. Configure quality profiles in each arr service"
echo "3. Add media folders and start searching!"
echo ""

echo -e "${GREEN}To access your services:${NC}"
echo "Sonarr:   http://192.168.1.100:80/sonarr"
echo "Radarr:   http://192.168.1.100:80/radarr"
echo "Prowlarr: http://192.168.1.100:80/prowlarr"
echo "SABnzbd:  http://192.168.1.100:80/sabnzbd"
echo ""

echo -e "${YELLOW}IMPORTANT: Version Control${NC}"
echo "After any configuration changes:"
echo "1. cd /docker/mediaserver"
echo "2. git add -A && git commit -m 'Updated configuration'"
echo "3. Keep .env.secrets backed up separately!"