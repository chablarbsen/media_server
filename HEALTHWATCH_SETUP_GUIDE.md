# HealthWatch Monitoring Setup Guide

**Created**: November 1, 2025
**Purpose**: Health monitoring and email alerting for media server services

---

## 🎯 Overview

HealthWatch is a custom monitoring solution that:
- Monitors all critical Docker containers for health status
- Checks HTTP endpoints for web service availability
- Sends email alerts to administrators when services go offline
- Provides a web dashboard for real-time status monitoring
- Implements smart alert cooldown to prevent email spam

---

## 🏗️ Architecture

### Components

1. **Health Monitor** (Python script)
   - Monitors Docker container status using Docker API
   - Checks HTTP endpoints for web services
   - Runs health checks every 15 minutes
   - Maintains service status history

2. **Email Alerting** (SendGrid)
   - Sends formatted HTML email alerts
   - Configurable admin email recipients
   - Alert cooldown (60 minutes per service by default)
   - Includes recommended troubleshooting actions

3. **Web Dashboard** (Flask)
   - Real-time service status display
   - Summary statistics (healthy/unhealthy/total)
   - Recent alert history
   - Auto-refreshes every 30 seconds
   - Accessible at: `http://your-domain.com/healthwatch`

---

## 📊 Monitored Services

### Critical Services (10 total)

| Service | Type | Description | Health Check |
|---------|------|-------------|--------------|
| **gluetun** | VPN | VPN Gateway | Container health |
| **plex** | Media | Media Server | Container + HTTP (`/web/index.html`) |
| **sonarr** | Arr | TV Show Manager | Container + HTTP (`/sonarr/ping`) |
| **radarr** | Arr | Movie Manager | Container + HTTP (`/radarr/ping`) |
| **prowlarr** | Arr | Indexer Manager | Container + HTTP (`/prowlarr/ping`) |
| **bazarr** | Arr | Subtitle Manager | Container + HTTP (`/bazarr/ping`) |
| **traefik** | Infrastructure | Reverse Proxy | Container health |
| **cloudflared** | Infrastructure | Cloudflare Tunnel | Container health |
| **deluge** | Download | Torrent Client | Container health |
| **sabnzbd** | Download | Usenet Client | Container health |

---

## ⚙️ Configuration

### Environment Variables (.env file)

```bash
# SendGrid Configuration
SENDGRID_API_KEY=SG.your-sendgrid-api-key-here

# Admin Email Addresses (comma-separated)
ADMIN_EMAILS=admin1@example.com,admin2@example.com
```

### Docker Compose Configuration

```yaml
healthwatch:
  build: ./healthwatch
  container_name: healthwatch
  environment:
    - CHECK_INTERVAL_MINUTES=15        # How often to check services
    - ALERT_COOLDOWN_MINUTES=60        # Minimum time between alerts per service
    - SENDGRID_API_KEY=${SENDGRID_API_KEY}
    - ADMIN_EMAILS=${ADMIN_EMAILS}
    - FROM_EMAIL=healthwatch@your-domain.com
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro  # Docker API access
    - ./healthwatch/data:/data                       # Persistent state
  networks:
    - management_network
  restart: unless-stopped
```

---

## 🚀 Setup Instructions

### Step 1: Create SendGrid Account

1. Go to https://sendgrid.com/
2. Sign up for a **free account** (100 emails/day limit)
3. Verify your email address
4. Navigate to **Settings → API Keys**
5. Click **Create API Key**
6. Give it a name (e.g., "HealthWatch Alerts")
7. Select **Restricted Access** → **Mail Send** → **Full Access**
8. Click **Create & View**
9. **Copy the API key** (starts with `SG.`) - you won't see it again!

### Step 2: Verify Sender Email (IMPORTANT)

SendGrid requires sender verification:

1. Go to **Settings → Sender Authentication**
2. Choose **Single Sender Verification** (easiest for personal use)
3. Add sender: `healthwatch@your-domain.com`
4. Fill in your contact information
5. Verify the email address

**Alternative**: Use domain authentication for better deliverability (requires DNS changes).

### Step 3: Update .env File

Add these lines to `/docker/mediaserver/.env`:

```bash
# HealthWatch Monitoring Configuration
SENDGRID_API_KEY=SG.paste-your-actual-api-key-here
ADMIN_EMAILS=your-email1@example.com,your-email2@example.com
```

### Step 4: Build and Deploy

```bash
cd /docker/mediaserver

# Build the healthwatch container
docker-compose build healthwatch

# Start the service
docker-compose up -d healthwatch

# Verify it's running
docker logs healthwatch
```

Expected output:
```
============================================================
HealthWatch Media Server Monitoring Service
============================================================
Check Interval: 15 minutes
Alert Cooldown: 60 minutes
Monitoring 10 services
Admin Emails: 2 configured
============================================================
[2025-11-01 12:00:00] INFO - Running service health checks...
[2025-11-01 12:00:01] INFO - All services healthy ✓
```

### Step 5: Access Web Dashboard

Open your browser and navigate to:
- **External**: `http://your-domain.com/healthwatch`
- **Internal**: `http://YOUR_SERVER_IP/healthwatch`

You should see:
- Summary cards showing healthy/unhealthy/total counts
- Grid of all monitored services with status badges
- Recent alert history

---

## 📧 Email Alert Format

### Alert Email Content

When a service fails, administrators receive an HTML email with:

**Subject**: ⚠️ ALERT: [service-name] is DOWN

**Body includes**:
- Service name and description
- Timestamp of failure
- Current status and health information
- Error details
- Recommended troubleshooting actions:
  - View logs: `docker logs [service]`
  - Restart service: `docker restart [service]`
  - Check all services: `docker ps -a`

### Alert Cooldown

- Alerts are sent **once per hour per service** (configurable)
- Prevents email spam during extended outages
- Cooldown tracked in persistent state file (`/data/healthwatch_state.json`)
- State survives container restarts

---

## 🧪 Testing

### Test Service Monitoring

1. **Stop a test service**:
   ```bash
   docker stop bazarr
   ```

2. **Wait for next health check** (max 15 minutes, or trigger manually):
   ```bash
   docker restart healthwatch  # Forces immediate check on startup
   ```

3. **Check logs**:
   ```bash
   docker logs healthwatch --tail 50
   ```

   Expected output:
   ```
   [2025-11-01 12:15:00] WARNING - Service bazarr is unhealthy: {'running': False, ...}
   [2025-11-01 12:15:00] INFO - Alert email sent for bazarr to 2 admins
   ```

4. **Check your email** - you should receive an alert within 1-2 minutes

5. **Restore service**:
   ```bash
   docker start bazarr
   ```

### Test Web Dashboard

1. Open `http://your-domain.com/healthwatch`
2. Verify summary shows 1 unhealthy service
3. Verify bazarr shows red "UNHEALTHY" badge
4. Check alert history shows the recent failure

---

## 🛠️ Troubleshooting Mode

### Preventing False Alerts During Maintenance

**IMPORTANT**: Before performing any maintenance or troubleshooting, **always** enter troubleshooting mode to prevent false positive alerts.

#### Enter Troubleshooting Mode

```bash
cd /docker/mediaserver
./troubleshooting-mode.sh enter
```

This will:
- ✅ Stop HealthWatch monitoring
- ✅ Prevent email alerts while you work
- ✅ Allow safe service restarts

#### Exit Troubleshooting Mode

When done with maintenance:

```bash
./troubleshooting-mode.sh exit
```

This will:
- ✅ Restart HealthWatch
- ✅ Wait 2 minutes (cold boot protection)
- ✅ Resume normal monitoring

#### Check Current Status

```bash
./troubleshooting-mode.sh status
```

### Cold Boot Protection

HealthWatch includes smart startup logic to prevent false alerts:

**On Startup**:
1. Waits **2 minutes minimum** for all services to initialize
2. Checks that at least **80% of services** are running
3. Adds **30-second grace period** for healthchecks to complete
4. **Maximum wait**: 15 minutes before starting monitoring anyway

**This prevents false alerts after**:
- Power outages
- Server reboots
- `docker compose down && docker compose up`
- Watchtower updates

### Startup Behavior

```
[2025-11-01 01:02:09] INFO - Cold boot protection: waiting 2 minutes for all services to start...
[2025-11-01 01:04:09] INFO - Services ready: 10/10 (120s elapsed)
[2025-11-01 01:04:09] INFO - ✓ 10/10 services running - ready to monitor
[2025-11-01 01:04:09] INFO - Waiting 30s grace period for services to fully initialize...
[2025-11-01 01:04:39] INFO - Running service health checks...
[2025-11-01 01:04:39] INFO - All services healthy ✓
```

## 🔧 Troubleshooting

### No Emails Being Sent

**Check SendGrid API Key**:
```bash
docker exec healthwatch printenv SENDGRID_API_KEY
# Should show: SG.xxxxxxxxxx
```

**Check Admin Emails**:
```bash
docker exec healthwatch printenv ADMIN_EMAILS
# Should show: email1@example.com,email2@example.com
```

**Check SendGrid Logs**:
```bash
docker logs healthwatch | grep -i sendgrid
```

**Verify Sender Email**:
- SendGrid requires sender verification
- Check SendGrid dashboard → Activity Feed for delivery issues

### Dashboard Not Loading

**Check if container is running**:
```bash
docker ps | grep healthwatch
```

**Check Traefik routing**:
```bash
docker logs traefik | grep healthwatch
```

**Access directly** (bypass Traefik):
```bash
docker exec healthwatch curl http://localhost:8888/
```

### Services Showing as Unhealthy Incorrectly

**Check Docker socket permissions**:
```bash
ls -l /var/run/docker.sock
docker exec healthwatch ls -l /var/run/docker.sock
```

**Verify network connectivity**:
```bash
docker exec healthwatch ping -c 1 sonarr
docker exec healthwatch curl http://sonarr:8989/sonarr/ping
```

### Alert Cooldown Issues

**Check state file**:
```bash
cat /docker/mediaserver/healthwatch/data/healthwatch_state.json
```

**Reset alert cooldowns**:
```bash
rm /docker/mediaserver/healthwatch/data/healthwatch_state.json
docker restart healthwatch
```

---

## 📝 Customization

### Change Check Interval

Edit `docker-compose.yml`:
```yaml
environment:
  - CHECK_INTERVAL_MINUTES=5  # Check every 5 minutes instead of 15
```

Then restart:
```bash
docker-compose up -d healthwatch
```

### Change Alert Cooldown

Edit `docker-compose.yml`:
```yaml
environment:
  - ALERT_COOLDOWN_MINUTES=30  # Alert every 30 minutes instead of 60
```

### Add More Services

Edit `/docker/mediaserver/healthwatch/healthwatch.py`:

```python
CRITICAL_SERVICES = {
    # ... existing services ...
    'lidarr': {
        'type': 'container',
        'description': 'Music Manager',
        'http_check': 'http://lidarr:8686/lidarr/ping'
    },
}
```

Rebuild and restart:
```bash
docker-compose build healthwatch
docker-compose up -d healthwatch
```

### Use Different Email Provider

**Mailgun Alternative**:

1. Replace SendGrid with Mailgun in `requirements.txt`
2. Update `healthwatch.py` to use Mailgun API
3. Update `.env` with Mailgun credentials

**SMTP Alternative**:

1. Replace SendGrid with `smtplib` (built-in Python)
2. Update `healthwatch.py` to use SMTP
3. Add SMTP credentials to `.env`

---

## 🔒 Security Considerations

### API Key Protection

- **Never commit** `.env` file to git (already in `.gitignore`)
- **SendGrid API key** has restricted permissions (Mail Send only)
- **Rotate API keys** periodically (every 90 days recommended)

### Email Exposure

- **From email** (`healthwatch@your-domain.com`) is visible to recipients
- **Admin emails** are stored in environment variables (secure)
- Consider using **alias emails** for administrators

### Container Security

- **Read-only Docker socket** - healthwatch can only read container status
- **Non-root user** - runs as UID 1001 inside container
- **No external network access required** - all checks are internal

---

## 📊 Monitoring Best Practices

### Alert Fatigue Prevention

- **15-minute intervals** - balances detection speed vs. noise
- **60-minute cooldowns** - prevents spam during outages
- **Smart health checks** - uses Docker healthchecks when available

### Response Procedures

When you receive an alert:

1. **Check the dashboard** - get full context
2. **View service logs** - identify root cause
3. **Check dependencies** - VPN, networks, storage
4. **Restart if needed** - `docker restart [service]`
5. **Monitor recovery** - dashboard updates every 30 seconds

### Scheduled Maintenance

Before planned maintenance:

```bash
# Temporarily disable healthwatch to prevent false alerts
docker stop healthwatch

# Perform maintenance...

# Re-enable monitoring
docker start healthwatch
```

---

## 📈 Future Enhancements

### Potential Improvements

- **Slack/Discord integration** - alternative to email
- **Metrics storage** - track uptime over time
- **Performance monitoring** - CPU/RAM/disk usage
- **Automated remediation** - auto-restart failed services
- **Mobile app notifications** - push notifications
- **Grafana integration** - advanced dashboards

---

## 🔗 Related Documentation

- `MEDIA_SERVER_BEST_PRACTICES.md` - Overall best practices
- `CLAUDE_SAFETY_PROTOCOL.md` - Safety procedures
- `DATABASE_CORRUPTION_PREVENTION.md` - Database protection

---

## ✅ Deployment Checklist

- [x] Mailgun account created
- [x] Mailgun API key generated
- [x] Domain verified in Mailgun (your-domain.com)
- [x] Admin email addresses added to .env (chadlarsen@proton.me, karsonhatch@gmail.com)
- [x] Mailgun API key added to .env
- [x] Healthwatch container built successfully
- [x] Healthwatch container running
- [x] Cold boot protection implemented (2-minute startup delay)
- [x] Troubleshooting mode script created
- [x] Test alert sent and received
- [x] All services showing correct status
- [x] Documentation reviewed

---

## 📋 Quick Reference

### Common Commands

```bash
# Enter troubleshooting mode (ALWAYS use before maintenance)
./troubleshooting-mode.sh enter

# Exit troubleshooting mode (resume monitoring)
./troubleshooting-mode.sh exit

# Check monitoring status
./troubleshooting-mode.sh status

# View healthwatch logs
docker logs healthwatch -f

# Check all service statuses
docker ps --format "table {{.Names}}\t{{.Status}}"

# Restart healthwatch (waits 2 minutes before monitoring)
docker restart healthwatch
```

### Key Features

- ✅ **10 critical services** monitored (gluetun, plex, sonarr, radarr, prowlarr, bazarr, traefik, cloudflared, deluge, sabnzbd)
- ✅ **Email alerts** to 2 admins via Mailgun (healthwatch@your-domain.com)
- ✅ **15-minute health checks** with 60-minute alert cooldown
- ✅ **2-minute cold boot protection** prevents false alerts after restarts
- ✅ **Troubleshooting mode** for safe maintenance without alerts
- ✅ **Smart startup** waits for 80% of services to be healthy
- ✅ **Persistent state** survives container restarts

### Monitoring Philosophy

**HealthWatch follows media server best practices:**
- ⚠️ **Never uses `depends_on: condition: service_healthy`** (incompatible with Watchtower)
- ✅ **Respects `stop_grace_period: 30s`** for database protection
- ✅ **Smart startup delays** prevent false positives
- ✅ **Manual control** via troubleshooting mode script

---

**Generated**: November 1, 2025
**Version**: 1.0
**Maintainer**: HealthWatch Monitoring Service

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
