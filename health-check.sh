#!/bin/bash

# Media Server Health Check Script
# This script performs health checks on all media server services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Media Server Health Check"
echo "========================================="
echo ""

# Function to check container status
check_container() {
    local container=$1
    local status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not found")

    if [ "$status" = "running" ]; then
        echo -e "${GREEN}✓${NC} $container: Running"
        return 0
    elif [ "$status" = "not found" ]; then
        echo -e "${RED}✗${NC} $container: Not found"
        return 1
    else
        echo -e "${YELLOW}⚠${NC} $container: $status"
        return 1
    fi
}

# Function to check service connectivity
check_connectivity() {
    local from_container=$1
    local to_service=$2
    local port=$3
    local endpoint=${4:-"ping"}

    if docker exec "$from_container" wget -q -O- "http://$to_service:$port/$endpoint" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $from_container -> $to_service:$port: Connected"
        return 0
    else
        echo -e "${RED}✗${NC} $from_container -> $to_service:$port: Failed"
        return 1
    fi
}

# Check all containers
echo "Container Status:"
echo "-----------------"
containers=(
    "traefik"
    "sonarr"
    "radarr"
    "lidarr"
    "readarr"
    "prowlarr"
    "bazarr"
    "plex"
    "sabnzbd"
    "deluge"
    "gluetun"
    "adguardhome"
    "immich-server"
    "cloudflared"
)

failed_containers=()
for container in "${containers[@]}"; do
    if ! check_container "$container"; then
        failed_containers+=("$container")
    fi
done

echo ""
echo "Service Connectivity:"
echo "--------------------"

# Check arr services connectivity to Prowlarr
echo "Indexer Integration (Prowlarr):"
check_connectivity "radarr" "prowlarr" "9696"
check_connectivity "sonarr" "prowlarr" "9696"
check_connectivity "lidarr" "prowlarr" "9696"
check_connectivity "readarr" "prowlarr" "9696"

echo ""
echo "Subtitle Integration (Bazarr):"
check_connectivity "bazarr" "sonarr" "8989" "ping"
check_connectivity "bazarr" "radarr" "7878" "ping"

echo ""
echo "Download Client Connectivity:"
echo "-----------------------------"

# Check if download clients are accessible
if docker exec sonarr wget -q -O- "http://sabnzbd:8080/api?mode=version" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Sonarr -> SABnzbd: Connected"
else
    echo -e "${YELLOW}⚠${NC} Sonarr -> SABnzbd: May need API key configuration"
fi

if docker exec radarr wget -q -O- "http://deluge:8112" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Radarr -> Deluge: Connected"
else
    echo -e "${YELLOW}⚠${NC} Radarr -> Deluge: May need configuration"
fi

echo ""
echo "Network Configuration:"
echo "---------------------"

# Check Docker networks
networks=(
    "mediaserver_arr_network"
    "mediaserver_vpn_network"
    "mediaserver_management_network"
)

for network in "${networks[@]}"; do
    if docker network inspect "$network" >/dev/null 2>&1; then
        container_count=$(docker network inspect "$network" -f '{{len .Containers}}' 2>/dev/null)
        echo -e "${GREEN}✓${NC} $network: Active ($container_count containers)"
    else
        echo -e "${RED}✗${NC} $network: Not found"
    fi
done

echo ""
echo "VPN Status (Gluetun):"
echo "--------------------"

# Check Gluetun VPN status
if docker exec gluetun wget -q -O- "http://localhost:8000/v1/openvpn/status" >/dev/null 2>&1; then
    vpn_status=$(docker exec gluetun wget -q -O- "http://localhost:8000/v1/openvpn/status" 2>/dev/null | grep -o '"status":"[^"]*' | cut -d'"' -f4)
    if [ "$vpn_status" = "running" ]; then
        echo -e "${GREEN}✓${NC} VPN: Connected"
        # Get public IP through VPN
        vpn_ip=$(docker exec gluetun wget -q -O- "http://localhost:8000/v1/publicip/ip" 2>/dev/null | grep -o '"public_ip":"[^"]*' | cut -d'"' -f4)
        [ -n "$vpn_ip" ] && echo -e "  Public IP: $vpn_ip"
    else
        echo -e "${YELLOW}⚠${NC} VPN: Status - $vpn_status"
    fi
else
    echo -e "${RED}✗${NC} VPN: Cannot check status"
fi

echo ""
echo "Service Endpoints:"
echo "-----------------"
echo "Traefik Dashboard: http://192.168.50.199:8090"
echo "Plex: http://192.168.50.199:32400"
echo "Services via Traefik: http://192.168.50.199:80"
echo ""

# Summary
echo "========================================="
echo "Health Check Summary:"
echo "========================================="

if [ ${#failed_containers[@]} -eq 0 ]; then
    echo -e "${GREEN}All containers are running!${NC}"
else
    echo -e "${YELLOW}Failed/stopped containers:${NC}"
    for container in "${failed_containers[@]}"; do
        echo "  - $container"
    done
    echo ""
    echo "To investigate issues, run:"
    echo "  docker logs <container_name> --tail 50"
fi

echo ""
echo "Run this script anytime with: bash /docker/mediaserver/health-check.sh"