#!/bin/bash

# Download Client Testing Script
# Tests connectivity and functionality of download clients

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "Download Client Testing"
echo "========================================="
echo ""

# Test SABnzbd
echo -e "${BLUE}SABnzbd (Usenet) Status:${NC}"
echo "------------------------"

if docker exec sabnzbd wget -q -O- "http://localhost:8080/api?mode=version" >/dev/null 2>&1; then
    version=$(docker exec sabnzbd wget -q -O- "http://localhost:8080/api?mode=version" 2>/dev/null | grep -oP '(?<="version":")[^"]+')
    echo -e "${GREEN}✓${NC} SABnzbd is running (version: $version)"
    echo "  - Web UI: http://192.168.1.100:80/sabnzbd"
    echo "  - Internal address for arr apps: http://sabnzbd:8080"

    # Check if connected from Sonarr/Radarr perspective
    if docker exec sonarr wget -q -O- "http://sabnzbd:8080" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Accessible from Sonarr"
    else
        echo -e "${YELLOW}⚠${NC} Not accessible from Sonarr - check network configuration"
    fi

    if docker exec radarr wget -q -O- "http://sabnzbd:8080" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Accessible from Radarr"
    else
        echo -e "${YELLOW}⚠${NC} Not accessible from Radarr - check network configuration"
    fi
else
    echo -e "${RED}✗${NC} SABnzbd is not responding"
fi

echo ""

# Test Deluge (through Gluetun VPN)
echo -e "${BLUE}Deluge (Torrent via VPN) Status:${NC}"
echo "--------------------------------"

if docker exec gluetun wget -q -O- "http://localhost:8112" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Deluge is running"
    echo "  - Web UI: http://192.168.1.101:8112"
    echo "  - Internal address for arr apps: http://gluetun:8112"
    echo "  - Default password: deluge"

    # Check VPN status
    vpn_status=$(docker exec gluetun wget -q -O- "http://localhost:8000/v1/openvpn/status" 2>/dev/null | grep -oP '(?<="status":")[^"]+' || echo "unknown")
    if [ "$vpn_status" = "running" ]; then
        echo -e "${GREEN}✓${NC} VPN is active"
        vpn_ip=$(docker exec gluetun wget -q -O- "http://localhost:8000/v1/publicip/ip" 2>/dev/null | grep -oP '(?<="public_ip":")[^"]+' || echo "unknown")
        echo "  - VPN Public IP: $vpn_ip"
    else
        echo -e "${YELLOW}⚠${NC} VPN status: $vpn_status"
    fi

    # Check if connected from Sonarr/Radarr perspective
    if docker exec sonarr wget -q -O- "http://gluetun:8112" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Accessible from Sonarr"
    else
        echo -e "${YELLOW}⚠${NC} Not accessible from Sonarr - check network configuration"
    fi

    if docker exec radarr wget -q -O- "http://gluetun:8112" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Accessible from Radarr"
    else
        echo -e "${YELLOW}⚠${NC} Not accessible from Radarr - check network configuration"
    fi
else
    echo -e "${RED}✗${NC} Deluge is not responding"
fi

echo ""

# Check download directories
echo -e "${BLUE}Download Directories:${NC}"
echo "--------------------"

# Check if download directories exist and permissions
directories=(
    "/downloads"
    "/downloads/complete"
    "/downloads/incomplete"
    "/downloads/torrents"
    "/downloads/usenet"
)

for dir in "${directories[@]}"; do
    if docker exec sonarr test -d "$dir" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $dir exists"
    else
        echo -e "${YELLOW}⚠${NC} $dir not found in Sonarr container"
    fi
done

echo ""

# Network connectivity between services
echo -e "${BLUE}Network Connectivity:${NC}"
echo "--------------------"

# Check if download clients are on the same network as arr services
echo "Checking network configuration..."

# Get network info for services
for service in "sonarr" "radarr" "sabnzbd" "deluge" "gluetun"; do
    networks=$(docker inspect "$service" --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "not found")
    if [ "$networks" != "not found" ]; then
        echo -e "${GREEN}✓${NC} $service networks: $networks"
    else
        echo -e "${RED}✗${NC} $service: Container not found"
    fi
done

echo ""

# Configuration recommendations
echo -e "${BLUE}Configuration Recommendations:${NC}"
echo "=============================="
echo ""
echo "1. In Sonarr/Radarr, add download clients:"
echo "   Settings → Download Clients → Add"
echo ""
echo "   For SABnzbd:"
echo "   - Name: SABnzbd"
echo "   - Host: sabnzbd"
echo "   - Port: 8080"
echo "   - API Key: (get from SABnzbd web interface)"
echo "   - Category: tv (for Sonarr) or movies (for Radarr)"
echo ""
echo "   For Deluge:"
echo "   - Name: Deluge (VPN)"
echo "   - Host: gluetun"
echo "   - Port: 8112"
echo "   - Password: deluge"
echo "   - Category: tv (for Sonarr) or movies (for Radarr)"
echo ""
echo "2. Configure download handling:"
echo "   - Enable 'Completed Download Handling'"
echo "   - Enable 'Remove Completed Downloads'"
echo "   - Set appropriate categories for organization"
echo ""
echo "3. Path mappings (if needed):"
echo "   - Remote Path: /downloads/"
echo "   - Local Path: /downloads/"
echo ""

echo -e "${GREEN}Download client testing complete!${NC}"
echo ""
echo "Run this script anytime with: bash /docker/mediaserver/test-downloads.sh"