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
