# Verification Protocol - MANDATORY AFTER ANY FIX

## Critical Rule
**NEVER mark a fix as complete without testing it survives a restart/reboot**

## Database Protection Verification Checklist

### After modifying daemon.json:
- [ ] Verify file contents: `cat /etc/docker/daemon.json`
- [ ] **RESTART DOCKER DAEMON**: `sudo systemctl restart docker`
- [ ] Verify daemon restarted: `systemctl status docker | grep "Active:"`
- [ ] Verify all containers restarted: `docker ps -a`
- [ ] Check container health: `docker ps --format "table {{.Names}}\t{{.Status}}"`
- [ ] Wait 2 minutes for services to stabilize
- [ ] Test database accessibility in each service
- [ ] **SIMULATE GRACEFUL SHUTDOWN**: `docker compose down`
- [ ] Verify shutdown took >10 seconds (proving timeout is active)
- [ ] Restart services: `docker compose up -d`
- [ ] Verify NO database corruption occurred

### After ANY configuration change:
1. **Make the change**
2. **Apply the change** (restart the affected service/daemon)
3. **Verify the change is active** (check runtime config, not just file)
4. **Test the change** (simulate the scenario it's meant to fix)
5. **Document the verification** (record what was tested and results)

## What Went Wrong on Oct 16, 2025

### Mistakes Made:
1. Modified `/etc/docker/daemon.json` with `"shutdown-timeout": 60`
2. **NEVER restarted Docker daemon** - Config was NOT applied
3. Declared fix complete without verification
4. Did not test with actual container restart
5. Did not verify timeout was active in runtime
6. Resulted in Plex corruption hours later

### Lesson Learned:
**Configuration file changes ≠ Configuration applied**

Many services require restart to apply config:
- Docker daemon requires: `systemctl restart docker`
- Containers require: `docker compose restart <service>`
- Plex requires container restart to reload Preferences.xml
- *arr services require restart to reload config.xml

## Database Corruption - Complete Fix Verification

### Required Steps (IN ORDER):
1. ✅ Add `"shutdown-timeout": 60` to /etc/docker/daemon.json
2. ❌ **RESTART DOCKER DAEMON** - THIS WAS SKIPPED
3. ❌ Verify new timeout is active
4. ❌ Test graceful shutdown takes adequate time
5. ❌ Verify databases survive shutdown/restart cycle

### To Complete the Fix:
```bash
# 1. Restart Docker daemon (requires sudo)
sudo systemctl restart docker

# 2. Verify daemon is running
systemctl status docker

# 3. Check all containers restarted
docker ps -a

# 4. Test graceful shutdown
cd /docker/mediaserver
time docker compose down  # Should take 30-60 seconds, not 10

# 5. Restart services
docker compose up -d

# 6. Verify no corruption
# Check each service's database file sizes and logs
```

## Verification Commands

### Check Docker daemon config is active:
```bash
# Note: Docker doesn't have a command to show shutdown-timeout
# Must verify by testing actual shutdown behavior
time docker compose down
# If takes ~60 seconds for database containers, timeout is active
# If takes ~10 seconds, timeout NOT active (daemon needs restart)
```

### Check container stop_grace_period:
```bash
docker inspect <container> | grep -A 2 "StopTimeout"
```

### Check database file integrity:
```bash
# For SQLite databases
sqlite3 <db_file> "PRAGMA integrity_check;"

# For Plex
docker exec plex sqlite3 "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" "PRAGMA integrity_check;"
```

## Never Declare Success Without:
1. Actual restart/reboot test
2. Verification the config is ACTIVE (not just saved to file)
3. Testing the scenario the fix is meant to prevent
4. Waiting adequate time to ensure stability
5. Documenting the verification steps taken

---

**Remember: A fix that isn't verified is not a fix at all.**
