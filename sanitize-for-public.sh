#!/bin/bash

# Sanitize Configuration for Public Repository
# Removes/replaces sensitive data with generic examples

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "Sanitizing Configuration for Public Repo"
echo "========================================="
echo ""

# Create sanitized branch
echo -e "${BLUE}Creating sanitized branch...${NC}"
git branch -D public-safe 2>/dev/null || true
git checkout -b public-safe

# Replace IP addresses with generic ones
echo -e "${YELLOW}Sanitizing IP addresses...${NC}"
FILES_TO_SANITIZE="docker-compose.yml *.sh *.md config-template.yaml"

for file in $FILES_TO_SANITIZE; do
    if [ -f "$file" ]; then
        # Replace specific IPs with generic examples
        sed -i 's/192\.168\.50\.199/192.168.1.100/g' "$file"
        sed -i 's/192\.168\.50\.51/192.168.1.101/g' "$file"
        sed -i 's/192\.168\.[0-9]+\.[0-9]+/192.168.1.X/g' "$file"
        sed -i 's/172\.[0-9]+\.[0-9]+\.[0-9]+/172.X.X.X/g' "$file"
        sed -i 's/10\.[0-9]+\.[0-9]+\.[0-9]+/10.X.X.X/g' "$file"
        echo "  Sanitized: $file"
    fi
done

# Replace domain names
echo -e "${YELLOW}Sanitizing domain names...${NC}"
for file in $FILES_TO_SANITIZE; do
    if [ -f "$file" ]; then
        sed -i 's/serenity\.watch/yourdomain.example.com/g' "$file"
        sed -i 's/serenity\.local/mediaserver.local/g' "$file"
        sed -i 's/user/user/g' "$file"
        echo "  Sanitized: $file"
    fi
done

# Replace paths with generic ones
echo -e "${YELLOW}Sanitizing paths...${NC}"
for file in $FILES_TO_SANITIZE; do
    if [ -f "$file" ]; then
        sed -i 's|/home/user/ssd-cache|/path/to/cache|g' "$file"
        sed -i 's|/home/user|/home/user|g' "$file"
        echo "  Sanitized: $file"
    fi
done

# Create a sanitized docker-compose template
echo -e "${YELLOW}Creating sanitized docker-compose template...${NC}"
cp docker-compose.yml docker-compose.template.yml

# Remove environment-specific values from template
sed -i 's/PUID=1001/PUID=${PUID}/g' docker-compose.template.yml
sed -i 's/PGID=1002/PGID=${PGID}/g' docker-compose.template.yml

# Create example environment file
cat > .env.example << 'EOF'
# Example Environment File
# Copy this to .env and fill in your values

# User/Group IDs
PUID=1000
PGID=1000

# Timezone
TIMEZONE=America/New_York

# VPN Credentials (ProtonVPN)
PROTON_USERNAME=your_proton_username
PROTON_PASSWORD=your_proton_password

# Plex
PLEX_CLAIM=claim-xxxxxxxxxxxxx

# Paths
CACHE_PATH=/path/to/cache
DATA_PATH=/path/to/media
CONFIG_PATH=/path/to/configs

# Network Settings
HOST_IP=192.168.1.100
VPN_IP=192.168.1.101
EOF

# Update .gitignore to be more comprehensive
cat > .gitignore << 'EOF'
# SECURITY - Never commit these
.env
.env.secrets
*.key
*.pem
*.crt
*.p12
*.bak
*_backup*

# Service configurations with sensitive data
*/config.xml
*/config.ini
*/sabnzbd.ini
*/settings.json
*/server.conf
authelia/configuration.yml
authelia/secrets/
gluetun/servers.json

# Backups and data
backups/
data/
downloads/
cache/

# Logs and databases
*.log
logs/
*.db
*.sqlite
*.db-wal
*.db-shm

# Temporary files
.cache/
*.tmp
*.temp
*.swp
.DS_Store

# Docker volumes
**/work/
**/cache/
**/transcodes/

# Runtime files
*.pid
*.lock

# Traefik certificates
traefik/letsencrypt/

# Allow these safe files
!.env.example
!docker-compose.template.yml
!*.sh
!*.md
!config-template.yaml
EOF

# Create public README
cat > README.md << 'EOF'
# Media Server Stack

A complete media server setup using Docker Compose with automated media management.

## ⚠️ Security Notice

This is a sanitized public version. Before using:
1. Clone the repository
2. Copy `.env.example` to `.env` and configure
3. Replace all example IPs and domains with your own
4. Generate new API keys using `manage-api-keys.sh`
5. Never commit `.env` or `.env.secrets` files

## Services Included

- **Plex**: Media server
- **Sonarr**: TV show management
- **Radarr**: Movie management
- **Lidarr**: Music management
- **Readarr**: Book management
- **Prowlarr**: Indexer management
- **Bazarr**: Subtitle management
- **SABnzbd**: Usenet downloader
- **Deluge**: Torrent client
- **Gluetun**: VPN client
- **Traefik**: Reverse proxy

## Quick Start

1. Clone repository:
   ```bash
   git clone <repo-url> /docker/mediaserver
   cd /docker/mediaserver
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. Generate API keys:
   ```bash
   bash manage-api-keys.sh
   ```

4. Start services:
   ```bash
   docker compose up -d
   ```

5. Configure services:
   ```bash
   bash auto-configure-services.sh
   ```

## Management Scripts

- `health-check.sh`: Check all service status
- `configure-arr-services.sh`: Initial configuration helper
- `manage-api-keys.sh`: API key management
- `test-downloads.sh`: Test download clients
- `auto-configure-services.sh`: Automated service setup

## Disaster Recovery

See `DISASTER_RECOVERY.md` for backup and recovery procedures.

## Security

- All sensitive data is in `.gitignore`
- API keys stored in `.env.secrets`
- Regular backups recommended
- Test recovery procedures quarterly

## Support

For issues, check:
1. Service logs: `docker logs <service-name>`
2. Health status: `bash health-check.sh`
3. Wiki: https://wiki.servarr.com/
EOF

echo ""
echo -e "${GREEN}Sanitization complete!${NC}"
echo ""
echo "Files have been sanitized on branch: public-safe"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review changes: git diff master"
echo "2. If satisfied, commit: git add -A && git commit -m 'Sanitized for public repository'"
echo "3. Push ONLY this branch to public: git push public public-safe:main"
echo ""
echo -e "${RED}IMPORTANT:${NC}"
echo "- NEVER push 'master' branch to public repo"
echo "- Keep 'master' branch for your private use only"
echo "- The 'public-safe' branch is for sharing"
echo ""
echo "To set up separate remotes:"
echo "  git remote add private <your-private-repo>"
echo "  git remote add public <your-public-repo>"
echo "  git push private master  # Private repo gets real config"
echo "  git push public public-safe:main  # Public gets sanitized"