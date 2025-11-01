# Container Restart Best Practices

**Date:** 2025-11-01
**Critical:** ALWAYS follow this order when restarting containers

---

## The Problem

**SABnzbd and Deluge** use `network_mode: "service:gluetun"` which means they share Gluetun's network namespace. If you restart all containers simultaneously, SABnzbd/Deluge may try to join Gluetun's network before Gluetun is fully ready, causing:

```
Error: cannot join network namespace of a non running container
Error: joining network namespace of container: No such container
```

---

## MANDATORY Restart Order

### ✅ CORRECT Order (Always use this)

```bash
cd /docker/mediaserver

# Step 1: Start VPN first and wait for health
docker compose up -d gluetun
sleep 60  # Wait for VPN to be healthy

# Step 2: Start VPN-dependent services
docker compose up -d sabnzbd deluge

# Step 3: Start everything else
docker compose up -d

# Step 4: Verify
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### ❌ WRONG Order (Never use this)

```bash
# DON'T DO THIS - causes race conditions
docker start $(docker ps -aq)
docker compose up -d  # Without ensuring Gluetun is healthy first
```

---

## Why This Happens

**Docker Container Startup Dependencies:**

1. **Gluetun** must:
   - Start container
   - Establish VPN connection
   - Pass health check
   - Create network namespace

2. **SABnzbd/Deluge** must:
   - Wait for Gluetun's network namespace to exist
   - Join that namespace
   - Only then can they start

**The race condition:** If SABnzbd/Deluge start before step 1 is complete, they try to join a network namespace that doesn't exist yet.

---

## When To Use This Order

**ALWAYS use this order when:**

1. ✅ System reboot (handled by Docker compose depends_on)
2. ✅ Docker daemon restart
3. ✅ Manual container restarts
4. ✅ After partition resize or maintenance
5. ✅ After docker-compose.yml changes
6. ✅ Recovery from container failures
7. ✅ VPN configuration changes

---

## Automated Restart Script

**Location:** `/docker/mediaserver/restart-containers-safely.sh`

```bash
#!/bin/bash
# Safe container restart with proper ordering
cd /docker/mediaserver

echo "Step 1: Starting Gluetun (VPN)..."
docker compose up -d gluetun

echo "Waiting 60 seconds for VPN to establish..."
sleep 60

# Verify Gluetun is healthy
if ! docker ps | grep gluetun | grep -q "healthy"; then
    echo "WARNING: Gluetun not showing as healthy yet"
    echo "Waiting additional 30 seconds..."
    sleep 30
fi

echo "Step 2: Starting VPN-dependent services (SABnzbd, Deluge)..."
docker compose up -d sabnzbd deluge

echo "Waiting 10 seconds..."
sleep 10

echo "Step 3: Starting all other services..."
docker compose up -d

echo "Step 4: Verifying all containers..."
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "Checking for failed containers..."
FAILED=$(docker ps -a --filter "status=exited" --format "{{.Names}}" | grep -E "sabnzbd|deluge" || true)

if [ -n "$FAILED" ]; then
    echo "ERROR: The following containers failed to start:"
    echo "$FAILED"
    echo ""
    echo "Run: docker logs <container-name>"
else
    echo "✓ All containers started successfully"
fi
```

---

## Recovery from Failed Start

If SABnzbd or Deluge fail with namespace errors:

### Quick Fix

```bash
cd /docker/mediaserver

# Option 1: Just restart the failed containers
docker compose restart sabnzbd deluge

# Option 2: If restart fails, recreate them
docker compose rm -f sabnzbd deluge
docker compose up -d sabnzbd deluge
```

### Full Recovery (if quick fix doesn't work)

```bash
cd /docker/mediaserver

# Stop VPN-dependent services
docker stop sabnzbd deluge

# Restart Gluetun
docker restart gluetun
sleep 60

# Recreate dependent services
docker compose rm -f sabnzbd deluge
docker compose up -d sabnzbd deluge
```

---

## Integration with Other Scripts

### Partition Resize Script

**MUST update `/docker/mediaserver/resize-partition.sh` Step 7:**

```bash
# OLD (WRONG):
docker start $(docker ps -aq)

# NEW (CORRECT):
echo "Starting Gluetun first..."
docker compose up -d gluetun
sleep 60

echo "Starting VPN-dependent services..."
docker compose up -d sabnzbd deluge
sleep 10

echo "Starting remaining services..."
docker compose up -d
```

### Any Maintenance Script

**Pattern to follow:**

```bash
# 1. Stop services (any order is fine)
docker compose down

# 2. Perform maintenance...

# 3. Restart with correct order
docker compose up -d gluetun
sleep 60
docker compose up -d sabnzbd deluge
sleep 10
docker compose up -d
```

---

## Docker Compose depends_on Limitation

**Why we can't rely on depends_on alone:**

```yaml
sabnzbd:
  depends_on:
    gluetun:
      condition: service_started  # Only waits for START, not HEALTHY
```

**Problem:** `service_started` doesn't wait for Gluetun's health check to pass. It only waits for the container to start, not for the VPN connection to establish.

**Why we don't use `condition: service_healthy`:**
- Not compatible with Watchtower auto-updates
- Causes issues during container recreation
- Documented in HEALTHWATCH_SETUP_GUIDE.md and CHANGELOG.md v1.7.1

**Solution:** Manual wait after Gluetun starts (60 seconds for VPN connection).

---

## Verification After Restart

```bash
# 1. Check all containers are running
docker ps

# 2. Verify Gluetun is healthy
docker ps | grep gluetun | grep healthy

# 3. Verify SABnzbd can access network through VPN
docker exec sabnzbd curl -s ifconfig.me

# 4. Verify Deluge can access network through VPN
docker exec deluge curl -s ifconfig.me

# Both should show the VPN IP, not your real IP

# 5. Check for any failed containers
docker ps -a --filter "status=exited"
```

---

## Common Errors and Fixes

### Error: "cannot join network namespace of a non running container"

**Cause:** Tried to start SABnzbd/Deluge before Gluetun was ready

**Fix:**
```bash
docker compose restart sabnzbd deluge
```

### Error: "No such container: ac8880767dc4..."

**Cause:** Stale network namespace reference (Gluetun was recreated)

**Fix:**
```bash
docker compose rm -f sabnzbd deluge
docker compose up -d sabnzbd deluge
```

### Error: Both containers repeatedly fail

**Cause:** Gluetun is not healthy or VPN not connected

**Fix:**
```bash
# Check Gluetun status
docker logs gluetun --tail 50

# Verify VPN connection
docker exec gluetun curl -s ifconfig.me

# If VPN not connected, check Gluetun config
```

---

## Checklist for ANY Container Restart

Before restarting containers, ask:

- [ ] Does this involve Gluetun?
- [ ] Are SABnzbd or Deluge involved?
- [ ] Am I using `docker start $(docker ps -aq)`? (DON'T!)
- [ ] Am I using the correct restart order?
- [ ] Did I wait 60s after starting Gluetun?
- [ ] Did I verify Gluetun is healthy before proceeding?

---

## Summary

**The Golden Rule:**

```
Gluetun → Wait 60s → SABnzbd/Deluge → Wait 10s → Everything Else
```

**Never:**
- Start all containers simultaneously
- Start SABnzbd/Deluge before Gluetun is healthy
- Use `docker start $(docker ps -aq)` when Gluetun is involved

**Always:**
- Start Gluetun first
- Wait for health check to pass
- Then start VPN-dependent services
- Verify no namespace errors

---

**Document Version:** 1.0
**Last Updated:** 2025-11-01
**Related:** NETWORKING_PERSISTENCE_GUIDE.md, VERIFICATION_PROTOCOL.md
