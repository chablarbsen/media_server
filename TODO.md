# Media Server TODO List

## Completed Tasks ✅
- [x] Verify Traefik routing configuration
- [x] Check media server service connections
- [x] Create health check startup script (`/docker/mediaserver/health-check.sh`)
- [x] Configure arr services integration
- [x] Create arr services configuration helper (`/docker/mediaserver/configure-arr-services.sh`)
- [x] Test download client connectivity
- [x] Create download client test script (`/docker/mediaserver/test-downloads.sh`)

## Pending Tasks 📋

### High Priority
- [x] Fix SABnzbd network connectivity to arr services ✅
  - ~~SABnzbd is not on the same Docker network as Sonarr/Radarr~~
  - Fixed: SABnzbd was using old Gluetun container ID, recreated container
  - Fixed: Updated SABnzbd host whitelist to allow arr services
  - Services now access SABnzbd via `gluetun:8080`

- [x] Configure download paths in containers ✅
  - ~~Mount `/downloads` directory in all arr containers~~
  - Added `/home/user/ssd-cache/downloads:/downloads` to all arr services
  - All services now have access to downloads directory

### Medium Priority
- [ ] Configure API keys for all services
  - Sonarr, Radarr, Lidarr, Prowlarr, Bazarr need API keys generated
  - Document keys securely

- [ ] Set up Prowlarr indexers
  - Add Usenet indexers
  - Add torrent indexers
  - Configure sync to all arr apps

- [ ] Configure download clients in arr apps
  - Add SABnzbd to Sonarr/Radarr
  - Add Deluge (via Gluetun) to Sonarr/Radarr
  - Set up categories and path mappings

### Low Priority
- [ ] Fix Authelia authentication (currently restarting)
  - Missing configuration file or incomplete setup
  - Not critical for media server functionality

- [ ] Configure quality profiles
  - Set up profiles for 4K, 1080p, 720p
  - Configure upgrade paths

- [ ] Set up media library paths
  - Verify Plex library paths
  - Configure arr apps to use correct paths

## Helper Scripts Created
1. **Health Check**: `bash /docker/mediaserver/health-check.sh`
   - Checks all container status
   - Tests service connectivity
   - Verifies VPN connection

2. **Configuration Helper**: `bash /docker/mediaserver/configure-arr-services.sh`
   - Shows API keys
   - Provides configuration steps
   - Lists service URLs

3. **Download Test**: `bash /docker/mediaserver/test-downloads.sh`
   - Tests SABnzbd and Deluge
   - Checks network connectivity
   - Provides configuration recommendations

## Quick Commands
```bash
# Check all services
bash /docker/mediaserver/health-check.sh

# View logs for any service
docker logs <service-name> --tail 50

# Restart a service
docker compose -f /docker/mediaserver/docker-compose.yml restart <service-name>

# Check Docker networks
docker network ls | grep mediaserver

# Access services
# Traefik: http://192.168.1.100:8090
# Services: http://192.168.1.100:80/<service-name>
# Deluge: http://192.168.1.101:8112
```

## Notes
- VPN (Gluetun) is working correctly with public IP: 149.22.82.10
- Deluge is accessible through VPN
- All arr services can communicate with each other
- Traefik is routing correctly
- Authelia is broken but not blocking other services