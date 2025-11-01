#!/bin/bash
# Safe container restart with proper ordering for Gluetun dependencies
# Created: 2025-11-01

set -e

cd /docker/mediaserver

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Safe Container Restart Script${NC}"
echo "=========================================="
echo ""

echo -e "${GREEN}Step 1: Starting Gluetun (VPN)...${NC}"
docker compose up -d gluetun

echo "Waiting 60 seconds for VPN to establish..."
for i in {60..1}; do
    echo -ne "  $i seconds remaining...\r"
    sleep 1
done
echo ""

# Verify Gluetun is healthy
echo "Checking Gluetun health..."
if docker ps | grep gluetun | grep -q "healthy"; then
    echo -e "${GREEN}✓ Gluetun is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Gluetun not showing as healthy yet${NC}"
    echo "Waiting additional 30 seconds..."
    sleep 30
fi

echo ""
echo -e "${GREEN}Step 2: Starting VPN-dependent services (SABnzbd, Deluge)...${NC}"
docker compose up -d sabnzbd deluge

echo "Waiting 10 seconds for services to start..."
sleep 10

echo ""
echo -e "${GREEN}Step 3: Starting all other services...${NC}"
docker compose up -d

echo ""
echo -e "${GREEN}Step 4: Verifying all containers...${NC}"
echo "=========================================="
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "Checking for failed containers..."
FAILED=$(docker ps -a --filter "status=exited" --format "{{.Names}}" | grep -E "sabnzbd|deluge|gluetun" || true)

if [ -n "$FAILED" ]; then
    echo -e "${RED}ERROR: The following containers failed to start:${NC}"
    echo "$FAILED"
    echo ""
    echo "To view logs: docker logs <container-name>"
    echo "To retry: docker compose restart <container-name>"
    exit 1
else
    echo -e "${GREEN}✓ All containers started successfully${NC}"
fi

echo ""
echo "Verifying VPN routing..."
VPN_IP=$(docker exec gluetun curl -s ifconfig.me 2>/dev/null || echo "N/A")
SAB_IP=$(docker exec sabnzbd curl -s ifconfig.me 2>/dev/null || echo "N/A")

echo "  Gluetun VPN IP: $VPN_IP"
echo "  SABnzbd IP: $SAB_IP"

if [ "$SAB_IP" = "$VPN_IP" ] && [ "$SAB_IP" != "N/A" ]; then
    echo -e "${GREEN}✓ VPN routing verified${NC}"
else
    echo -e "${YELLOW}⚠ VPN routing may have issues${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Restart complete!"
echo "==========================================${NC}"
