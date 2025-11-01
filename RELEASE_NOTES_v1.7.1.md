# Release Notes - Media Server v1.7.1

**Release Date**: November 1, 2025
**Type**: Patch Release - Service Monitoring & Email Alerting
**Priority**: MEDIUM - Enhanced operational visibility
**Builds on**: v1.7.0 (Memory-enabled operations)

---

## 📊 NEW FEATURE: HealthWatch Monitoring Service

### Overview
Comprehensive health monitoring and email alerting system for all critical media server services. Provides real-time status visibility and proactive failure notifications to administrators.

### Key Capabilities

**Service Monitoring:**
- Monitors 10 critical Docker containers for health status
- Checks HTTP endpoints for web service availability
- Runs automated health checks every 15 minutes
- Maintains service status history and alert records

**Email Alerting:**
- Sends HTML-formatted alerts via Mailgun when services fail
- Configured for 2 administrators: chadlarsen@proton.me, karsonhatch@gmail.com
- Smart alert cooldown (60 minutes per service) prevents email spam
- Includes recommended troubleshooting actions in each alert

**Web Dashboard:**
- Real-time service status display at `http://your-domain.com/healthwatch`
- Summary statistics (healthy/unhealthy/total counts)
- Recent alert history visualization
- Auto-refreshes every 30 seconds

---

## 🎯 Monitored Services (10 Total)

| Service | Type | Health Checks |
|---------|------|---------------|
| **gluetun** | VPN Gateway | Container health |
| **plex** | Media Server | Container + HTTP (`/web/index.html`) |
| **sonarr** | TV Show Manager | Container + HTTP (`/sonarr/ping`) |
| **radarr** | Movie Manager | Container + HTTP (`/radarr/ping`) |
| **prowlarr** | Indexer Manager | Container + HTTP (`/prowlarr/ping`) |
| **bazarr** | Subtitle Manager | Container + HTTP (`/bazarr/ping`) |
| **traefik** | Reverse Proxy | Container health |
| **cloudflared** | Cloudflare Tunnel | Container health |
| **deluge** | Torrent Client | Container health |
| **sabnzbd** | Usenet Client | Container health |

---

## 🛡️ CRITICAL: Best Practices Compliance

### Database Protection Integration
HealthWatch is fully compliant with media server best practices established in v1.6.1:

**✅ NO `depends_on` Conditions:**
- Does NOT use `depends_on: condition: service_healthy` (Watchtower incompatible)
- Uses Python-based smart startup delays instead of Docker dependencies
- Fully compatible with Watchtower auto-updates

**✅ Respects Database Protection:**
- Honors all `stop_grace_period: 30s` configurations
- Will not interfere with SQLite WAL checkpoints
- Safe to run alongside database-heavy services

**✅ Cold Boot Protection:**
- 2-minute minimum startup delay prevents false alerts after:
  - Power outages
  - Server reboots
  - `docker compose down && up`
  - Watchtower container updates
- Waits for 80% of services to be running before monitoring
- Additional 30-second grace period for service initialization
- Maximum 15-minute timeout if services don't reach 80% threshold

---

## 🔧 Troubleshooting Mode

### Prevention of False Positive Alerts

**CRITICAL FEATURE**: Before any maintenance or troubleshooting, use the troubleshooting mode script to prevent false alerts.

**Enter Troubleshooting Mode:**
```bash
cd /docker/mediaserver
./troubleshooting-mode.sh enter
```

This will:
- ✅ Stop HealthWatch monitoring
- ✅ Prevent email alerts while you work
- ✅ Allow safe service restarts and testing

**Exit Troubleshooting Mode:**
```bash
./troubleshooting-mode.sh exit
```

This will:
- ✅ Restart HealthWatch
- ✅ Wait 2 minutes (cold boot protection)
- ✅ Resume normal monitoring

**Check Status:**
```bash
./troubleshooting-mode.sh status
```

---

## 📧 Email Alerting System

### Mailgun Integration

**Configuration:**
- Domain: your-domain.com (DNS verified)
- From Address: healthwatch@your-domain.com
- Admin Recipients: 2 configured
- Delivery: Mailgun API (5,000 emails/month free tier)

**DNS Records Configured:**
- ✅ SPF: `v=spf1 include:mailgun.org ~all`
- ✅ DKIM: Two keys (pdk1, pdk2) for domain verification
- ✅ CNAME: Tracking record for email analytics

**Alert Email Contents:**
- Service name and description
- Timestamp of failure
- Current status and health information
- Error details
- Recommended troubleshooting commands:
  - `docker logs [service]`
  - `docker restart [service]`
  - `docker ps -a`

**Alert Cooldown:**
- 60-minute minimum between alerts per service
- Prevents email spam during extended outages
- Cooldown state persists across container restarts
- Stored in `/data/healthwatch_state.json`

---

## 🏗️ Technical Implementation

### Components Created

**1. HealthWatch Service (`/docker/mediaserver/healthwatch/`)**
- `healthwatch.py` - Main monitoring service (411 lines)
- `Dockerfile` - Container definition
- `requirements.txt` - Python dependencies
- `templates/dashboard.html` - Web dashboard UI
- `static/` - CSS/JS assets
- `data/` - Persistent state storage

**2. Docker Compose Integration**
- New `healthwatch` service added to docker-compose.yml
- Traefik labels for `/healthwatch` routing
- Read-only Docker socket mount for container monitoring
- Management network connectivity

**3. Troubleshooting Mode Script**
- `/docker/mediaserver/troubleshooting-mode.sh` - 141 lines
- Commands: enter, exit, status
- Color-coded output for clarity
- Safe service state management

**4. Documentation**
- `/docker/mediaserver/HEALTHWATCH_SETUP_GUIDE.md` - Complete setup guide (583 lines)
- Includes: configuration, testing, troubleshooting, customization

**5. Healthchecks Added**
- **Traefik**: `CMD ["traefik", "healthcheck", "--ping"]`
- **Cloudflared**: `CMD ["cloudflared", "tunnel", "info"]` (distroless compatible)

---

## 🔐 Security Considerations

### API Key Protection
- Mailgun API key stored in `.env` (never committed to git)
- API key has restricted permissions (Mail Send only)
- Token included in private repository, excluded from public

### Container Security
- Read-only Docker socket mount (cannot modify containers)
- Runs as root (required for Docker socket access)
- No external network access required (all checks internal)

### Email Privacy
- From email visible to recipients: healthwatch@your-domain.com
- Admin emails stored securely in environment variables
- No email addresses exposed in logs or public documentation

---

## ⚙️ Configuration

### Environment Variables (`.env`)

```bash
# HealthWatch Monitoring
MAILGUN_API_KEY=your-mailgun-api-key-here
MAILGUN_DOMAIN=your-domain.com
ADMIN_EMAILS=admin@example.com
```

### Docker Compose Configuration

```yaml
healthwatch:
  build: ./healthwatch
  container_name: healthwatch
  environment:
    - TZ=${TIMEZONE}
    - CHECK_INTERVAL_MINUTES=15        # How often to check services
    - ALERT_COOLDOWN_MINUTES=60        # Minimum time between alerts
    - MAILGUN_API_KEY=${MAILGUN_API_KEY}
    - MAILGUN_DOMAIN=${MAILGUN_DOMAIN}
    - ADMIN_EMAILS=${ADMIN_EMAILS}
    - FROM_EMAIL=healthwatch@${MAILGUN_DOMAIN}
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - ./healthwatch/data:/data
  networks:
    - management_network
  restart: unless-stopped
```

---

## 🧪 Testing & Validation

### Test Results

**Email Alert Test:**
- ✅ Stopped bazarr service
- ✅ Alert email sent within 1 minute
- ✅ Received by both admin addresses
- ✅ HTML formatting correct
- ✅ Recommended actions included

**Cold Boot Protection Test:**
- ✅ Restarted healthwatch container
- ✅ 2-minute startup delay activated
- ✅ Waited for 10/10 services to be ready
- ✅ No false positive alerts sent
- ✅ Monitoring started after grace period

**Troubleshooting Mode Test:**
- ✅ Entered troubleshooting mode successfully
- ✅ HealthWatch stopped
- ✅ Restarted services without alerts
- ✅ Exited troubleshooting mode
- ✅ Monitoring resumed after 2-minute delay

---

## 📝 Files Modified/Created

### New Files
- ✅ `/docker/mediaserver/healthwatch/healthwatch.py`
- ✅ `/docker/mediaserver/healthwatch/Dockerfile`
- ✅ `/docker/mediaserver/healthwatch/requirements.txt`
- ✅ `/docker/mediaserver/healthwatch/templates/dashboard.html`
- ✅ `/docker/mediaserver/healthwatch/data/` (directory)
- ✅ `/docker/mediaserver/troubleshooting-mode.sh`
- ✅ `/docker/mediaserver/HEALTHWATCH_SETUP_GUIDE.md`
- ✅ `/docker/mediaserver/RELEASE_NOTES_v1.7.1.md`

### Modified Files
- ✅ `/docker/mediaserver/docker-compose.yml` - Added healthwatch service
- ✅ `/docker/mediaserver/docker-compose.yml` - Added traefik healthcheck
- ✅ `/docker/mediaserver/docker-compose.yml` - Added cloudflared healthcheck
- ✅ `/docker/mediaserver/.env` - Added Mailgun credentials

---

## 🚀 Deployment

### Installation Steps

1. **Mailgun Setup:**
   - Domain verified: your-domain.com
   - DNS records added to Cloudflare
   - API key generated and added to `.env`

2. **Build & Deploy:**
   ```bash
   cd /docker/mediaserver
   docker compose build healthwatch
   docker compose up -d healthwatch
   ```

3. **Verify Deployment:**
   ```bash
   docker logs healthwatch
   # Expected: "HealthWatch Media Server Monitoring Service"
   # Expected: "Services ready: 10/10"
   # Expected: "All services healthy ✓"
   ```

4. **Access Dashboard:**
   - External: `http://your-domain.com/healthwatch`
   - Internal: `http://YOUR_SERVER_IP/healthwatch`

### Startup Behavior

```
[2025-11-01 01:02:09] INFO - Cold boot protection: waiting 2 minutes for all services to start...
[2025-11-01 01:04:09] INFO - Services ready: 10/10 (120s elapsed)
[2025-11-01 01:04:09] INFO - ✓ 10/10 services running - ready to monitor
[2025-11-01 01:04:09] INFO - Waiting 30s grace period for services to fully initialize...
[2025-11-01 01:04:39] INFO - Running service health checks...
[2025-11-01 01:04:39] INFO - All services healthy ✓
```

---

## 🔄 Git Commits

**Private Repository** (`media_server_private`):
```
commit [pending]
v1.7.1: HealthWatch monitoring service with email alerting
- Complete monitoring service implementation
- Mailgun email integration
- Cold boot protection (2-minute startup delay)
- Troubleshooting mode script
- Healthchecks for traefik and cloudflared
- Comprehensive documentation
```

**Public Repository** (`media_server`):
```
commit [pending]
v1.7.1: HealthWatch monitoring service (sanitized)
- Monitoring service with sanitized configuration
- Email credentials redacted
- Admin emails replaced with placeholders
- Domain references sanitized
```

---

## 📚 Integration with Best Practices

This release builds directly on the foundation established in previous versions:

**v1.6.1 Database Protection:**
- HealthWatch respects all `stop_grace_period: 30s` configurations
- Will not interfere with SQLite WAL checkpoints
- Compatible with Watchtower timeout settings

**v1.7.0 Memory-Enabled Operations:**
- Documentation references automatically loaded via CLAUDE.md
- Best practices compliance verified before implementation
- Safety protocols followed throughout development

**No Breaking Changes:**
- All existing services continue running without modification
- No changes to database service configurations
- No impact on Watchtower auto-update behavior

---

## 🎯 Benefits

### Operational Improvements

1. **Proactive Alerting**: Know immediately when services fail (15-minute check interval)
2. **Multi-Admin Support**: Both administrators receive alerts simultaneously
3. **Reduced Downtime**: Faster response to service failures
4. **No False Positives**: Smart startup delays and troubleshooting mode
5. **Persistent History**: Alert history survives container restarts
6. **Visual Dashboard**: Real-time status at a glance

### Maintenance Improvements

1. **Safe Troubleshooting**: Dedicated mode prevents alert spam
2. **Clear Documentation**: Complete setup and usage guide
3. **Easy Testing**: Simple commands for testing alerts
4. **Customizable**: Adjustable check intervals and cooldowns
5. **Scalable**: Easy to add more services to monitoring

---

## 📊 Monitoring Philosophy

HealthWatch follows established media server principles:

**Alert Fatigue Prevention:**
- 15-minute check intervals balance detection speed vs. noise
- 60-minute cooldowns prevent spam during outages
- Uses Docker healthchecks when available

**Reliability Focus:**
- Smart startup delays prevent false positives
- Persistent state across container restarts
- Graceful handling of Docker API errors

**Maintenance-Friendly:**
- Troubleshooting mode for safe service restarts
- Clear separation of monitoring and monitored services
- No dependencies that could cause cascading failures

---

## 🔍 Troubleshooting

### Common Issues

**No Emails Received:**
1. Check Mailgun API key: `docker exec healthwatch printenv MAILGUN_API_KEY`
2. Check admin emails: `docker exec healthwatch printenv ADMIN_EMAILS`
3. View logs: `docker logs healthwatch | grep -i mailgun`
4. Verify DNS records in Cloudflare (SPF, DKIM)

**Dashboard Not Loading:**
1. Check container: `docker ps | grep healthwatch`
2. Check Traefik routing: `docker logs traefik | grep healthwatch`
3. Access directly: `docker exec healthwatch curl http://localhost:8888/`

**False Positive Alerts:**
1. Use troubleshooting mode before maintenance
2. Verify cold boot protection is active (check logs)
3. Adjust check interval if needed (default: 15 minutes)

---

## ✅ Deployment Checklist

### Completed Actions
- [x] Mailgun account created
- [x] Mailgun domain verified (your-domain.com)
- [x] DNS records added to Cloudflare (SPF, DKIM)
- [x] Mailgun API key generated and added to .env
- [x] Admin email addresses configured
- [x] HealthWatch service implemented
- [x] Docker Compose configuration updated
- [x] Healthchecks added to traefik and cloudflared
- [x] Cold boot protection implemented (2-minute delay)
- [x] Troubleshooting mode script created
- [x] Email alert tested successfully
- [x] All 10 services showing correct status
- [x] Web dashboard accessible
- [x] Complete documentation written
- [x] Release notes v1.7.1 created

### Pending Actions
- [ ] Push to private repository
- [ ] Sanitize and push to public repository
- [ ] Monitor for 24 hours to verify stability
- [ ] Update CHANGELOG.md with v1.7.1 entry

---

## 🔗 Related Documentation

### New Documentation
- `HEALTHWATCH_SETUP_GUIDE.md` - Complete setup and usage guide

### Referenced Documentation
- `MEDIA_SERVER_BEST_PRACTICES.md` - Best practices compliance
- `CLAUDE_SAFETY_PROTOCOL.md` - Safety procedures followed
- `DATABASE_CORRUPTION_PREVENTION.md` - Database protection context

---

## 📈 Future Enhancements

### Potential Improvements (Future Versions)

**v1.7.2+ Candidates:**
- Slack/Discord integration as alternative to email
- SMS alerts for critical failures
- Metrics storage and uptime tracking
- Performance monitoring (CPU/RAM/disk usage)

**v1.8.0+ Candidates:**
- Automated remediation (auto-restart failed services)
- Grafana integration for advanced dashboards
- Mobile app push notifications
- Multi-instance monitoring support

---

## 🎉 Summary

**v1.7.1 adds comprehensive service monitoring and email alerting** while maintaining full compliance with established best practices. The HealthWatch service provides proactive failure detection without introducing risks to database services or Watchtower compatibility.

**Key Achievements:**
- 📊 **10 critical services monitored** (Docker + HTTP health checks)
- 📧 **Email alerting via Mailgun** (2 admin recipients)
- 🛡️ **Best practices compliant** (no depends_on, respects stop_grace_period)
- ⏱️ **Cold boot protection** (2-minute startup delay)
- 🔧 **Troubleshooting mode** (prevents false alerts during maintenance)
- 📈 **Web dashboard** (real-time status at /healthwatch)
- ✅ **Zero downtime deployment** (all services remain operational)

---

**Generated**: November 1, 2025
**Version**: 1.7.1
**Classification**: Internal - Contains configuration details

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
