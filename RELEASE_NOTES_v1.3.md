# Media Server Stack - Release Notes v1.3

**Release Date:** October 13, 2025
**Type:** Container Resilience & Auto-Recovery

---

## 🎯 Overview

Version 1.3 focuses on improving container restart reliability after system updates and reboots. This release fixes issues where download clients (Deluge, SABnzbd) and the landing page failed to automatically restart after Docker daemon restarts, ensuring true "set it and forget it" operation.

---

## ✨ New Features & Enhancements

### 1. **Improved Container Dependency Management**
- **Changed VPN-dependent services to use `service_started` instead of `service_healthy`**
  - Deluge now starts when Gluetun container starts (not waiting for VPN connection)
  - SABnzbd now starts when Gluetun container starts (not waiting for VPN connection)
  - Download clients queue operations briefly until VPN establishes connection

**Why this matters:**
- `depends_on` with `condition: service_healthy` only works during `docker-compose up`
- When Docker daemon restarts (system updates, reboots), the restart policy doesn't respect health checks
- Gluetun can take 30-60 seconds to establish VPN and become "healthy"
- Services dependent on health checks would fail to auto-restart

### 2. **Added Missing Restart Policy**
- **Landing page container** now has `restart: unless-stopped` policy
- Previously had no restart policy and would remain stopped after Docker restarts

### 3. **Network Label Standardization**
- Added `traefik.docker.network` label to Bazarr for consistent Traefik routing
- Matches configuration pattern used by Sonarr and Radarr

---

## 🔧 Configuration Changes

### docker-compose.yml

**Deluge:**
```yaml
deluge:
  depends_on:
    gluetun:
      condition: service_started  # Changed from service_healthy
```

**SABnzbd:**
```yaml
sabnzbd:
  depends_on:
    gluetun:
      condition: service_started  # Changed from service_healthy
```

**Landing:**
```yaml
landing:
  image: nginx:alpine
  container_name: landing
  restart: unless-stopped  # Added - was missing
```

**Bazarr:**
```yaml
bazarr:
  labels:
    - "traefik.docker.network=mediaserver_management_network"  # Added for consistency
```

---

## 🐛 Issues Fixed

### 1. **Deluge Failed to Auto-Restart After System Updates**
**Problem:**
- After running `apt-get update && apt-get upgrade`, Docker daemon restarts
- Gluetun takes ~30 seconds to establish VPN connection and become "healthy"
- Deluge's dependency on `service_healthy` prevents auto-restart
- User must manually run `docker start deluge`

**Solution:**
- Changed to `service_started` dependency
- Deluge starts immediately when Gluetun container starts
- Brief delay (few seconds) before downloads begin while VPN connects
- Fully automatic recovery - no manual intervention required

**Testing:**
- Verified after system update on October 13, 2025
- Deluge remained stopped with exit code 255
- Fixed configuration and confirmed auto-restart behavior

### 2. **SABnzbd Had Same Issue (Proactive Fix)**
- Applied identical fix to SABnzbd
- Prevents future issues with Usenet downloads after restarts

### 3. **Landing Page Failed to Auto-Restart**
**Problem:**
- Landing page container had no restart policy defined
- Would remain stopped after Docker daemon restarts

**Solution:**
- Added `restart: unless-stopped` to container configuration
- Now automatically restarts with all other services

---

## 🔒 Security & Best Practices

### No Impact on VPN Security
- Download clients still route 100% of traffic through Gluetun VPN
- `network_mode: "service:gluetun"` ensures no traffic leaks
- Brief startup delay while VPN connects is acceptable tradeoff for reliability
- All downloads are queued until VPN is established

### Configuration Review
- Verified no sensitive data in docker-compose.yml changes
- All API keys remain in `.env.secrets` (not committed)
- Database files properly excluded from git via `.gitignore`
- Safe for both private and public repository commits

---

## 📊 Testing & Validation

### System Update Test (October 13, 2025)
**Scenario:**
```bash
sudo apt-get update && sudo apt-get upgrade
```

**Before Fix:**
- Docker daemon restarted at 09:08:41 UTC
- Gluetun: Started, became unhealthy for ~30s, then healthy
- Deluge: Exited with code 255, remained stopped
- SABnzbd: Started successfully (happened to catch healthy window)
- Landing: Exited with code 255, remained stopped

**After Fix:**
- All containers automatically restart when Docker daemon starts
- Brief delay while services initialize
- No manual intervention required

### Container Status Verification
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**Results:**
```
NAMES             STATUS
deluge            Up 2 minutes
sabnzbd           Up 9 minutes
landing           Up 10 seconds
gluetun           Up 5 minutes (unhealthy → healthy)
[All other services running normally]
```

---

## 🔄 Deployment Impact

### Breaking Changes
**None.** All changes improve reliability without affecting functionality.

### Upgrade Path
1. Pull latest docker-compose.yml from repository
2. Review changes: `git diff docker-compose.yml`
3. No container rebuild required
4. Restart affected containers to apply new restart policies:
   ```bash
   docker-compose up -d
   ```

### Rollback Procedure
If issues occur (unlikely):
```bash
git checkout HEAD~1 docker-compose.yml
docker-compose up -d
```

---

## 📈 Container Lifecycle Behavior

### Previous Behavior (v1.2)
```
System Update → Docker Restarts → Gluetun Starts (unhealthy)
                                 ↓
                          Deluge tries to start
                                 ↓
                    Sees Gluetun unhealthy → Exits
                                 ↓
                         Manual restart required
```

### New Behavior (v1.3)
```
System Update → Docker Restarts → Gluetun Starts
                                 ↓
                          Deluge starts immediately
                                 ↓
                    Waits for VPN (~10-30s)
                                 ↓
                         Downloads resume automatically
```

---

## 📝 Configuration Persistence

All configurations remain **persistent** across:
- Container restarts
- Docker daemon restarts
- System reboots
- System updates

**Stored in:**
- Docker volumes (databases, configs)
- docker-compose.yml (container definitions)
- .env.secrets (API keys, passwords)

---

## 🚀 Best Practices Implemented

### 1. **Restart Policy Standards**
All production containers now have explicit restart policies:
- `restart: unless-stopped` - Services that should always run
- `depends_on: service_started` - Dependent services that can handle startup delays

### 2. **Dependency Management**
- Use `service_started` for dependencies that can tolerate brief unavailability
- Reserve `service_healthy` only for critical dependencies during initial startup
- Understand that restart policies don't respect health checks after daemon restarts

### 3. **Git Hygiene**
- Only commit configuration files (docker-compose.yml, documentation)
- Exclude runtime files (databases, logs, PIDs, backups)
- Review diffs before committing to catch sensitive data
- Use descriptive commit messages with issue context

---

## 🔮 Future Enhancements

- Consider implementing external health monitoring (Uptime Kuma)
- Add automated restart scripts for critical service failures
- Implement container dependency startup delays if needed
- Document recovery procedures for edge cases

---

## 📚 Additional Documentation

- See `NETWORKING_PERSISTENCE_GUIDE.md` for VPN and networking details
- See `DISASTER_RECOVERY.md` for backup and recovery procedures
- See `REPOSITORY_PROTECTION.md` for git security best practices

---

## 🙏 Acknowledgments

Issue identified and resolved based on real-world system update scenario on October 13, 2025.

Special thanks to Docker documentation for clarifying restart policy behavior:
- https://docs.docker.com/compose/compose-file/05-services/#restart
- https://docs.docker.com/compose/compose-file/05-services/#depends_on

---

**Version:** 1.3
**Previous Version:** 1.2
**Upgrade Path:** Configuration changes only (no container updates required)
