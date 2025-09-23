#!/bin/bash

# API Key Management Script
# This script manages API keys for all services and prepares for disaster recovery

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration directory
CONFIG_DIR="/docker/mediaserver"
SECRETS_FILE="$CONFIG_DIR/.env.secrets"
BACKUP_DIR="$CONFIG_DIR/backups/$(date +%Y%m%d_%H%M%S)"

echo "========================================="
echo "API Key Management & Configuration Backup"
echo "========================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}Creating backup in: $BACKUP_DIR${NC}"
echo ""

# Function to get or generate API key
get_or_generate_api_key() {
    local service=$1
    local config_file=""
    local api_key=""

    case $service in
        sonarr|radarr|lidarr|prowlarr)
            config_file="$CONFIG_DIR/$service/config.xml"
            if [ -f "$config_file" ]; then
                api_key=$(grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo "")
                if [ -z "$api_key" ]; then
                    # Generate new API key
                    api_key=$(openssl rand -hex 16)
                    echo -e "${YELLOW}Generated new API key for $service${NC}"
                    # Note: We'll need to update the config file when service is stopped
                fi
            else
                echo -e "${RED}Config file not found for $service${NC}"
                return 1
            fi
            ;;
        readarr)
            config_file="$CONFIG_DIR/$service/config.xml"
            if [ -f "$config_file" ]; then
                api_key=$(grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo "")
            fi
            ;;
        bazarr)
            config_file="$CONFIG_DIR/$service/config/config.ini"
            if [ -f "$config_file" ]; then
                api_key=$(grep -oP '(?<=apikey = )[^\s]+' "$config_file" 2>/dev/null || echo "")
                if [ -z "$api_key" ]; then
                    api_key=$(openssl rand -hex 16)
                    echo -e "${YELLOW}Generated new API key for $service${NC}"
                fi
            fi
            ;;
        sabnzbd)
            config_file="$CONFIG_DIR/$service/sabnzbd.ini"
            if [ -f "$config_file" ]; then
                api_key=$(grep -oP '(?<=api_key = )[^\s]+' "$config_file" 2>/dev/null || echo "")
                if [ -z "$api_key" ]; then
                    api_key=$(openssl rand -hex 16)
                    echo -e "${YELLOW}Generated new API key for $service${NC}"
                fi
            fi
            ;;
    esac

    echo "$api_key"
}

# Collect all API keys
echo -e "${BLUE}Collecting API Keys:${NC}"
echo "--------------------"

declare -A api_keys
services=("sonarr" "radarr" "lidarr" "readarr" "prowlarr" "bazarr" "sabnzbd")

for service in "${services[@]}"; do
    api_key=$(get_or_generate_api_key "$service")
    if [ -n "$api_key" ]; then
        api_keys[$service]=$api_key
        echo -e "${GREEN}✓${NC} $service: ${api_key:0:8}..."
    else
        echo -e "${RED}✗${NC} $service: Failed to get/generate key"
    fi
done

echo ""

# Create secrets file (not tracked by git)
echo -e "${BLUE}Creating Secrets File:${NC}"
echo "---------------------"
cat > "$SECRETS_FILE" << EOF
# API Keys for Media Server Services
# Generated: $(date)
# IMPORTANT: Do not commit this file to git!

# Service API Keys
SONARR_API_KEY="${api_keys[sonarr]}"
RADARR_API_KEY="${api_keys[radarr]}"
LIDARR_API_KEY="${api_keys[lidarr]}"
READARR_API_KEY="${api_keys[readarr]}"
PROWLARR_API_KEY="${api_keys[prowlarr]}"
BAZARR_API_KEY="${api_keys[bazarr]}"
SABNZBD_API_KEY="${api_keys[sabnzbd]}"

# Download Client Settings
DELUGE_PASSWORD="deluge"

# Service URLs (Internal)
SONARR_URL="http://sonarr:8989"
RADARR_URL="http://radarr:7878"
LIDARR_URL="http://lidarr:8686"
READARR_URL="http://readarr:8787"
PROWLARR_URL="http://prowlarr:9696"
BAZARR_URL="http://bazarr:6767"
SABNZBD_URL="http://gluetun:8080"
DELUGE_URL="http://gluetun:8112"
EOF

chmod 600 "$SECRETS_FILE"
echo -e "${GREEN}✓${NC} Created $SECRETS_FILE"
echo ""

# Create configuration template (can be tracked by git)
echo -e "${BLUE}Creating Configuration Template:${NC}"
echo "-------------------------------"
cat > "$CONFIG_DIR/config-template.yaml" << 'EOF'
# Media Server Configuration Template
# This file can be safely committed to git
# Actual values are stored in .env.secrets

services:
  sonarr:
    api_key: ${SONARR_API_KEY}
    url: ${SONARR_URL}
    download_clients:
      - name: SABnzbd
        host: gluetun
        port: 8080
        api_key: ${SABNZBD_API_KEY}
        category: tv
      - name: Deluge
        host: gluetun
        port: 8112
        password: ${DELUGE_PASSWORD}
        category: tv

  radarr:
    api_key: ${RADARR_API_KEY}
    url: ${RADARR_URL}
    download_clients:
      - name: SABnzbd
        host: gluetun
        port: 8080
        api_key: ${SABNZBD_API_KEY}
        category: movies
      - name: Deluge
        host: gluetun
        port: 8112
        password: ${DELUGE_PASSWORD}
        category: movies

  prowlarr:
    api_key: ${PROWLARR_API_KEY}
    url: ${PROWLARR_URL}
    apps:
      - name: Sonarr
        url: ${SONARR_URL}
        api_key: ${SONARR_API_KEY}
      - name: Radarr
        url: ${RADARR_URL}
        api_key: ${RADARR_API_KEY}
      - name: Lidarr
        url: ${LIDARR_URL}
        api_key: ${LIDARR_API_KEY}
      - name: Readarr
        url: ${READARR_URL}
        api_key: ${READARR_API_KEY}

  bazarr:
    api_key: ${BAZARR_API_KEY}
    url: ${BAZARR_URL}
    sonarr:
      url: ${SONARR_URL}
      api_key: ${SONARR_API_KEY}
    radarr:
      url: ${RADARR_URL}
      api_key: ${RADARR_API_KEY}

paths:
  media:
    tv: /data/tv
    movies: /data/movies
    music: /data/music
    books: /data/books
  downloads:
    root: /downloads
    complete: /downloads/complete
    incomplete: /downloads/incomplete
    torrents: /downloads/torrents
    usenet: /downloads/usenet
EOF

echo -e "${GREEN}✓${NC} Created config-template.yaml"
echo ""

# Create backup of current configurations
echo -e "${BLUE}Backing Up Current Configurations:${NC}"
echo "---------------------------------"

for service in "${services[@]}"; do
    if [ -d "$CONFIG_DIR/$service" ]; then
        cp -r "$CONFIG_DIR/$service" "$BACKUP_DIR/" 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Backed up $service configuration"
    fi
done

# Create .gitignore for sensitive files
echo -e "${BLUE}Creating Git Configuration:${NC}"
echo "--------------------------"
cat > "$CONFIG_DIR/.gitignore" << 'EOF'
# Sensitive files - never commit these
.env
.env.secrets
*.key
*.pem
*.crt
*.p12

# Service configuration directories (contain sensitive data)
*/config.xml
*/config.ini
*/sabnzbd.ini
*/settings.json

# Backup directories
backups/

# Log files
*.log
logs/

# Database files
*.db
*.sqlite

# Cache and temporary files
.cache/
*.tmp
*.temp

# Auth configuration (removed - authelia not used)

# But DO track these
!config-template.yaml
!docker-compose.yml
!*.sh
!TODO.md
!README.md
EOF

echo -e "${GREEN}✓${NC} Created .gitignore"
echo ""

# Create recovery documentation
echo -e "${BLUE}Creating Recovery Documentation:${NC}"
echo "-------------------------------"
cat > "$CONFIG_DIR/DISASTER_RECOVERY.md" << 'EOF'
# Disaster Recovery Plan for Media Server

## Quick Recovery Steps

1. **Clone the repository**
   ```bash
   git clone <your-repo-url> /docker/mediaserver
   cd /docker/mediaserver
   ```

2. **Restore secrets**
   - Copy your backed up `.env.secrets` file
   - Or regenerate API keys using `bash manage-api-keys.sh`

3. **Restore data volumes**
   - Restore `/data` directory from backup
   - Restore download cache if needed

4. **Start services**
   ```bash
   docker compose up -d
   ```

5. **Verify services**
   ```bash
   bash health-check.sh
   ```

## Backup Strategy

### What to backup:
1. **Configuration** (via Git)
   - docker-compose.yml
   - All .sh scripts
   - config-template.yaml

2. **Secrets** (separate secure backup)
   - .env.secrets file
   - Store in password manager or encrypted backup

3. **Data** (regular backups)
   - /data directory (your media)
   - Service config directories (optional, can be regenerated)

### Backup Commands:
```bash
# Quick backup of configs and secrets
tar -czf mediaserver-config-$(date +%Y%m%d).tar.gz \
  --exclude=backups \
  --exclude=*.log \
  /docker/mediaserver

# Backup media data (large)
rsync -av /data/ /backup/media/
```

## Configuration Management

### After any configuration change:
1. Run `bash manage-api-keys.sh` to update secrets
2. Commit changes to git:
   ```bash
   git add -A
   git commit -m "Updated configuration"
   git push
   ```

### To apply configuration to services:
```bash
bash configure-arr-services.sh
```

## Emergency Contacts & Resources
- Docker Compose Docs: https://docs.docker.com/compose/
- LinuxServer.io Docs: https://docs.linuxserver.io/
- Servarr Wiki: https://wiki.servarr.com/
EOF

echo -e "${GREEN}✓${NC} Created DISASTER_RECOVERY.md"
echo ""

echo "========================================="
echo -e "${GREEN}Configuration Management Setup Complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Review the generated .env.secrets file"
echo "2. Initialize git repository: git init"
echo "3. Add remote: git remote add origin <your-repo-url>"
echo "4. Initial commit: git add -A && git commit -m 'Initial media server configuration'"
echo "5. Run the configuration helper: bash configure-arr-services.sh"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "- Keep .env.secrets file secure (it's in .gitignore)"
echo "- Back up the secrets file separately"
echo "- Regularly commit configuration changes to git"
echo "- Test disaster recovery plan quarterly"