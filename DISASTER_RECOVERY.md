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
