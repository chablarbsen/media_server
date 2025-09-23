# Configuration Templates

This directory contains template configuration files for consistent service deployment.

## Usage

When deploying new instances or recovering from failures:

1. **Copy template files** to the appropriate service directory
2. **Customize** any environment-specific settings
3. **Deploy containers** with pre-configured settings

## Available Templates

### Deluge (`deluge/core.conf.template`)
- Private tracker optimized configuration
- 8 active downloads, 15 total active limit
- DHT/LSD/PEX disabled for private tracker compliance
- Speed limits: 25MB/s down, 10MB/s up
- Port: 58946 (configured for IPTorrents)

### Future Templates
- `sonarr/quality-profiles.json` - Quality profiles with custom formats
- `prowlarr/indexer-configs/` - Indexer configuration templates
- `radarr/custom-formats.json` - Movie quality custom formats

## Configuration Principles

1. **Configure before deployment** - Never rely on runtime changes
2. **Create backups** - Always maintain `.optimized-permanent` copies
3. **Document changes** - Update this README when adding new templates
4. **Test thoroughly** - Verify all integrations work before going live

## Recovery Procedure

If a service loses configuration:
1. Stop the affected container
2. Copy the appropriate template to the service config directory
3. Customize any unique settings (API keys, etc.)
4. Start the container
5. Verify functionality

This approach eliminates the need for manual reconfiguration and ensures consistency across deployments.