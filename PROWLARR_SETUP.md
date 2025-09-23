# Prowlarr Indexer Setup Guide

## Overview
Prowlarr centralizes indexer management for all arr services. This guide covers manual setup since indexer selection depends on personal access and preferences.

## Access Prowlarr
- **Local Access**: http://192.168.1.100/prowlarr (through reverse proxy)
- **Container Network**: http://prowlarr:9696 (internal)

## Initial Setup Steps

### 1. First Launch
1. Open Prowlarr web interface
2. Complete initial setup wizard
3. Note the API key generated (will be in Settings > General)

### 2. Add Indexers
Navigate to Indexers > Add Indexer

#### Recommended Free Indexers:
- **YTS** (Movies)
- **EZTV** (TV Shows)
- **LimeTorrents** (General)
- **1337x** (General)
- **The Pirate Bay** (General)
- **RARBG** (if available)

#### Private Indexers:
Configure based on your memberships and invites.

### 3. Configure Categories
Ensure these categories are enabled for proper arr service sync:
- **Movies**: 2000-2099
- **TV**: 5000-5099
- **Music**: 3000-3099
- **Books**: 7000-7099

### 4. Sync with Arr Services
Prowlarr should automatically sync indexers to connected arr services.

## Integration Check

After setup, verify integration:
```bash
# Check Sonarr has indexers
curl -s "http://sonarr:8989/api/v3/indexer" -H "X-Api-Key: [API_KEY]"

# Check Radarr has indexers
curl -s "http://radarr:7878/api/v3/indexer" -H "X-Api-Key: [API_KEY]"
```

## Security Notes
- Indexer configurations contain sensitive data
- Some indexers require cookies/tokens
- Never commit indexer configs to public repos
- Backup indexer settings separately

## Troubleshooting

### Common Issues:
1. **Indexers not syncing**: Check arr service API keys in Prowlarr settings
2. **Search failures**: Verify indexer health in Prowlarr
3. **Rate limits**: Configure appropriate delays between searches

### Logs:
```bash
docker logs prowlarr
```

## Manual Configuration Required
This setup requires manual web UI configuration as:
- Indexer access varies by user
- Some require registration/authentication
- Privacy preferences differ
- Legal considerations vary by region

Complete this setup through the Prowlarr web interface.