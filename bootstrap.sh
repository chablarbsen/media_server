#!/bin/bash

# Media Server Bootstrap Script
# One-click setup for complete media server stack

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_PATH="/docker/mediaserver"
DATA_PATH="/data"
CACHE_PATH="/cache/downloads"

clear
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════╗
║                                              ║
║     MEDIA SERVER AUTOMATED SETUP            ║
║     Docker-Based Media Management Stack      ║
║                                              ║
╚══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "This script will set up a complete media server with:"
echo "• Plex, Sonarr, Radarr, Lidarr, Readarr"
echo "• Prowlarr, Bazarr, SABnzbd, Deluge"
echo "• VPN protection via Gluetun"
echo "• Reverse proxy via Traefik"
echo ""

# Check prerequisites
echo -e "${BLUE}[1/10] Checking Prerequisites...${NC}"
echo -n "  Docker: "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Not installed${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -n "  Docker Compose: "
if command -v docker compose &> /dev/null || command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Not installed${NC}"
    echo "Please install Docker Compose first"
    exit 1
fi

echo -n "  Git: "
if command -v git &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Installing git...${NC}"
    sudo apt-get update && sudo apt-get install -y git
fi

# Get user configuration
echo ""
echo -e "${BLUE}[2/10] Configuration Setup${NC}"

# Network configuration
read -p "Enter your server's IP address [192.168.1.100]: " SERVER_IP
SERVER_IP=${SERVER_IP:-192.168.1.100}

read -p "Enter your VPN interface IP [192.168.1.101]: " VPN_IP
VPN_IP=${VPN_IP:-192.168.1.101}

# User/Group IDs
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)
read -p "Enter PUID [$CURRENT_UID]: " PUID
PUID=${PUID:-$CURRENT_UID}

read -p "Enter PGID [$CURRENT_GID]: " PGID
PGID=${PGID:-$CURRENT_GID}

# Timezone
CURRENT_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "America/New_York")
read -p "Enter timezone [$CURRENT_TZ]: " TIMEZONE
TIMEZONE=${TIMEZONE:-$CURRENT_TZ}

# VPN Configuration
echo ""
echo -e "${YELLOW}VPN Configuration (ProtonVPN via Gluetun)${NC}"
read -p "Enter ProtonVPN username: " PROTON_USERNAME
read -sp "Enter ProtonVPN password: " PROTON_PASSWORD
echo ""

# Create directory structure
echo ""
echo -e "${BLUE}[3/10] Creating Directory Structure...${NC}"
sudo mkdir -p "$INSTALL_PATH"
sudo mkdir -p "$DATA_PATH"/{tv,movies,music,books}
sudo mkdir -p "$CACHE_PATH"/{complete,incomplete,torrents,usenet}
sudo chown -R $PUID:$PGID "$INSTALL_PATH" "$DATA_PATH" "$CACHE_PATH"

# Clone or update repository
echo ""
echo -e "${BLUE}[4/10] Getting Configuration Files...${NC}"
if [ -d "$INSTALL_PATH/.git" ]; then
    echo "Updating existing repository..."
    cd "$INSTALL_PATH"
    git fetch origin
    git reset --hard origin/main
else
    echo "Cloning repository..."
    if [ -d "$INSTALL_PATH" ]; then
        sudo rm -rf "$INSTALL_PATH"
    fi
    git clone https://github.com/yourusername/mediaserver-public.git "$INSTALL_PATH"
    cd "$INSTALL_PATH"
fi

# Create environment file
echo ""
echo -e "${BLUE}[5/10] Creating Environment Configuration...${NC}"
cat > "$INSTALL_PATH/.env" << EOF
# Media Server Environment Configuration
# Generated: $(date)

# User/Group IDs
PUID=$PUID
PGID=$PGID

# Timezone
TIMEZONE=$TIMEZONE

# Network
SERVER_IP=$SERVER_IP
VPN_IP=$VPN_IP

# VPN Credentials
PROTON_USERNAME=$PROTON_USERNAME
PROTON_PASSWORD=$PROTON_PASSWORD

# Plex
PLEX_CLAIM=

# Paths
CACHE_PATH=$CACHE_PATH
DATA_PATH=$DATA_PATH
CONFIG_PATH=$INSTALL_PATH
EOF

echo -e "${GREEN}✓${NC} Environment file created"

# Update docker-compose.yml with actual values
echo ""
echo -e "${BLUE}[6/10] Configuring Docker Compose...${NC}"
if [ -f "$INSTALL_PATH/docker-compose.template.yml" ]; then
    cp "$INSTALL_PATH/docker-compose.template.yml" "$INSTALL_PATH/docker-compose.yml"
fi

# Replace template values
sed -i "s|192.168.1.100|$SERVER_IP|g" "$INSTALL_PATH/docker-compose.yml"
sed -i "s|192.168.1.101|$VPN_IP|g" "$INSTALL_PATH/docker-compose.yml"
sed -i "s|/path/to/cache|$CACHE_PATH|g" "$INSTALL_PATH/docker-compose.yml"
sed -i "s|/path/to/media|$DATA_PATH|g" "$INSTALL_PATH/docker-compose.yml"

echo -e "${GREEN}✓${NC} Docker Compose configured"

# Create Docker networks
echo ""
echo -e "${BLUE}[7/10] Creating Docker Networks...${NC}"
docker network create mediaserver_management_network 2>/dev/null || echo "  Management network exists"
docker network create mediaserver_arr_network 2>/dev/null || echo "  Arr network exists"
docker network create mediaserver_vpn_network 2>/dev/null || echo "  VPN network exists"

# Start services
echo ""
echo -e "${BLUE}[8/10] Starting Services...${NC}"
echo "This may take several minutes on first run..."

# Start core services first
docker compose up -d gluetun
echo -n "  Waiting for VPN connection..."
sleep 10
docker exec gluetun wget -q -O- http://localhost:8000/v1/openvpn/status | grep -q "running" && echo -e " ${GREEN}✓${NC}" || echo -e " ${YELLOW}⚠${NC}"

# Start remaining services
docker compose up -d

# Wait for services to be ready
echo ""
echo -e "${BLUE}[9/10] Waiting for Services to Initialize...${NC}"
services=("sonarr:8989" "radarr:7878" "prowlarr:9696" "plex:32400")
for service_port in "${services[@]}"; do
    IFS=':' read -r service port <<< "$service_port"
    echo -n "  $service... "
    timeout 60 bash -c "until curl -s http://localhost:$port >/dev/null 2>&1; do sleep 2; done" && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠${NC}"
done

# Generate and configure API keys
echo ""
echo -e "${BLUE}[10/10] Configuring Services...${NC}"
if [ -f "$INSTALL_PATH/manage-api-keys.sh" ]; then
    bash "$INSTALL_PATH/manage-api-keys.sh"

    # Auto-configure if script exists
    if [ -f "$INSTALL_PATH/auto-configure-services.sh" ]; then
        echo "Running automatic configuration..."
        bash "$INSTALL_PATH/auto-configure-services.sh"
    fi
fi

# Final setup
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}    Setup Complete! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Service URLs:${NC}"
echo "  Sonarr:   http://$SERVER_IP/sonarr"
echo "  Radarr:   http://$SERVER_IP/radarr"
echo "  Lidarr:   http://$SERVER_IP/lidarr"
echo "  Readarr:  http://$SERVER_IP/readarr"
echo "  Prowlarr: http://$SERVER_IP/prowlarr"
echo "  Bazarr:   http://$SERVER_IP/bazarr"
echo "  SABnzbd:  http://$SERVER_IP/sabnzbd"
echo "  Deluge:   http://$VPN_IP:8112"
echo "  Plex:     http://$SERVER_IP:32400"
echo ""
echo -e "${CYAN}Management Commands:${NC}"
echo "  Check health:  bash $INSTALL_PATH/health-check.sh"
echo "  View logs:     docker compose logs -f [service]"
echo "  Restart all:   docker compose restart"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Get Plex claim token from https://plex.tv/claim"
echo "2. Add to .env file and restart Plex"
echo "3. Add indexers in Prowlarr"
echo "4. Configure quality profiles in arr apps"
echo "5. Add media libraries"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  Setup Guide: $INSTALL_PATH/README.md"
echo "  Security: $INSTALL_PATH/SECURITY_AUDIT.md"
echo "  Recovery: $INSTALL_PATH/DISASTER_RECOVERY.md"
echo ""
echo -e "${GREEN}Happy streaming! 🍿${NC}"

# Create systemd service (optional)
echo ""
read -p "Would you like to create a systemd service for auto-start? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo tee /etc/systemd/system/mediaserver.service > /dev/null << EOF
[Unit]
Description=Media Server Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_PATH
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
User=root
Group=docker

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable mediaserver.service
    echo -e "${GREEN}✓${NC} Systemd service created and enabled"
fi