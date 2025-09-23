#!/bin/bash

# Arr Services Configuration Script
# This script helps configure the integration between arr services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "Arr Services Configuration Helper"
echo "========================================="
echo ""

# Function to get API key from service config
get_api_key() {
    local service=$1
    local config_path="/config/config.xml"

    case $service in
        prowlarr|lidarr|readarr)
            config_path="/config/config.xml"
            ;;
        radarr|sonarr|bazarr)
            config_path="/config/config.xml"
            ;;
        sabnzbd)
            config_path="/config/sabnzbd.ini"
            ;;
    esac

    if [ "$service" = "sabnzbd" ]; then
        docker exec "$service" grep -oP '(?<=api_key = )[^\s]+' "$config_path" 2>/dev/null || echo ""
    else
        docker exec "$service" grep -oP '(?<=<ApiKey>)[^<]+' "$config_path" 2>/dev/null || echo ""
    fi
}

# Display all API keys for reference
echo -e "${BLUE}Service API Keys:${NC}"
echo "----------------"

services=("sonarr" "radarr" "lidarr" "readarr" "prowlarr" "bazarr" "sabnzbd")
declare -A api_keys

for service in "${services[@]}"; do
    api_key=$(get_api_key "$service")
    if [ -n "$api_key" ]; then
        api_keys[$service]=$api_key
        echo -e "${GREEN}✓${NC} $service: ${api_key:0:8}..."
    else
        echo -e "${YELLOW}⚠${NC} $service: No API key found"
    fi
done

echo ""
echo -e "${BLUE}Configuration Steps:${NC}"
echo "===================="
echo ""

# Prowlarr Configuration
echo -e "${YELLOW}1. Configure Prowlarr (Indexer Management):${NC}"
echo "   - Access Prowlarr at: http://192.168.50.199:80/prowlarr"
echo "   - Add your indexers (Usenet/Torrent sites)"
echo "   - Go to Settings > Apps"
echo "   - Add applications for Sonarr, Radarr, Lidarr, Readarr"
echo "   - Use these settings for each:"
echo ""

for app in "sonarr" "radarr" "lidarr" "readarr"; do
    if [ -n "${api_keys[$app]}" ]; then
        port=""
        case $app in
            sonarr) port="8989" ;;
            radarr) port="7878" ;;
            lidarr) port="8686" ;;
            readarr) port="8787" ;;
        esac
        echo "   ${app^}:"
        echo "   - Prowlarr Server: http://prowlarr:9696"
        echo "   - ${app^} Server: http://$app:$port"
        echo "   - API Key: ${api_keys[$app]}"
        echo ""
    fi
done

# Download Client Configuration
echo -e "${YELLOW}2. Configure Download Clients:${NC}"
echo ""
echo "   SABnzbd (Usenet):"
echo "   - Internal URL: http://sabnzbd:8080"
if [ -n "${api_keys[sabnzbd]}" ]; then
    echo "   - API Key: ${api_keys[sabnzbd]}"
else
    echo "   - Get API key from SABnzbd web interface"
fi
echo ""
echo "   Deluge (Torrent via VPN):"
echo "   - Internal URL: http://gluetun:8112"
echo "   - Default password: deluge"
echo "   - Configure in Sonarr/Radarr > Settings > Download Clients"
echo ""

# Media Management Configuration
echo -e "${YELLOW}3. Configure Media Paths:${NC}"
echo "   All services should use these paths:"
echo "   - TV Shows: /tv"
echo "   - Movies: /movies"
echo "   - Music: /music"
echo "   - Books: /books"
echo "   - Downloads: /downloads"
echo ""

# Bazarr Configuration
echo -e "${YELLOW}4. Configure Bazarr (Subtitles):${NC}"
echo "   - Access Bazarr at: http://192.168.50.199:80/bazarr"
echo "   - Add Sonarr connection:"
echo "     - Address: http://sonarr:8989"
echo "     - API Key: ${api_keys[sonarr]:-'Get from Sonarr'}"
echo "   - Add Radarr connection:"
echo "     - Address: http://radarr:7878"
echo "     - API Key: ${api_keys[radarr]:-'Get from Radarr'}"
echo ""

# Quality Profiles
echo -e "${YELLOW}5. Recommended Quality Profiles:${NC}"
echo "   - Create profiles in each arr service"
echo "   - Suggested profiles:"
echo "     - 4K/2160p for Movies (if storage allows)"
echo "     - 1080p for TV Shows"
echo "     - FLAC/320kbps for Music"
echo "   - Enable 'Upgrade Until Quality Met'"
echo ""

# Testing
echo -e "${BLUE}Testing Integration:${NC}"
echo "=================="

# Test Prowlarr sync
echo -n "Testing Prowlarr → Sonarr sync: "
if docker exec sonarr wget -q -O- "http://prowlarr:9696/ping" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

echo -n "Testing Prowlarr → Radarr sync: "
if docker exec radarr wget -q -O- "http://prowlarr:9696/ping" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

echo ""
echo -e "${BLUE}Quick Links:${NC}"
echo "==========="
echo "Sonarr:   http://192.168.50.199:80/sonarr"
echo "Radarr:   http://192.168.50.199:80/radarr"
echo "Lidarr:   http://192.168.50.199:80/lidarr"
echo "Readarr:  http://192.168.50.199:80/readarr"
echo "Prowlarr: http://192.168.50.199:80/prowlarr"
echo "Bazarr:   http://192.168.50.199:80/bazarr"
echo "SABnzbd:  http://192.168.50.199:80/sabnzbd"
echo "Deluge:   http://192.168.50.51:8112"
echo ""

echo -e "${GREEN}Configuration helper complete!${NC}"
echo "Follow the steps above to complete your arr services setup."
echo ""
echo "Run this script anytime with: bash /docker/mediaserver/configure-arr-services.sh"