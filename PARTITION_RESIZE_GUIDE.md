# Root Partition Resize Guide - Expand to 1.5TB

**Date:** 2025-11-01
**Current Size:** 98GB
**Target Size:** 1.5TB
**Available Space:** ~1.7TB on NVMe

---

## Pre-Resize Checklist

### 1. Verify Current State

```bash
# Check current partition usage
df -h /

# Check LVM configuration
sudo vgdisplay ubuntu-vg-1
sudo lvdisplay /dev/ubuntu-vg-1/ubuntu-lv

# Check available space in volume group
sudo vgs ubuntu-vg-1

# Expected output should show ~1.7TB free in VG
```

### 2. Backup Critical Data (IMPORTANT)

```bash
# Backup Docker configurations
sudo tar -czf /data/backups/docker-configs-$(date +%Y%m%d).tar.gz \
  /docker/mediaserver \
  --exclude=/docker/mediaserver/*/Cache \
  --exclude=/docker/mediaserver/*/logs

# Verify backup created
ls -lh /data/backups/docker-configs-*.tar.gz
```

### 3. Stop Services (Prevent File System Issues)

```bash
# Enter troubleshooting mode
docker stop healthwatch

# Stop all Docker containers gracefully
docker stop $(docker ps -q)

# Verify all stopped
docker ps
# Should show no running containers

# Wait 30 seconds for graceful shutdown
sleep 30
```

---

## Resize Procedure

### Step 1: Extend Logical Volume

```bash
# Calculate new size: Current 98GB + 1400GB = ~1500GB (1.5TB)
# Using +1400G to add 1.4TB to current 98GB

sudo lvextend -L +1400G /dev/ubuntu-vg-1/ubuntu-lv

# Expected output:
#   Size of logical volume ubuntu-vg-1/ubuntu-lv changed from 98.00 GiB to 1.46 TiB
```

**Alternative (if you want to use ALL available space):**

```bash
# Use 100% of free space in volume group
sudo lvextend -l +100%FREE /dev/ubuntu-vg-1/ubuntu-lv
```

### Step 2: Resize File System

```bash
# Resize ext4 filesystem to use new LV space
# This is ONLINE and non-destructive
sudo resize2fs /dev/ubuntu-vg-1/ubuntu-lv

# Expected output:
#   Resizing the filesystem on /dev/ubuntu-vg-1/ubuntu-lv to XXXXXX blocks
#   The filesystem on /dev/ubuntu-vg-1/ubuntu-lv is now XXXXXX blocks long
```

**Note:** `resize2fs` can be done while the filesystem is mounted (online resize). No downtime required.

### Step 3: Verify New Size

```bash
# Check new partition size
df -h /

# Should show approximately:
# Filesystem                            Size  Used Avail Use% Mounted on
# /dev/mapper/ubuntu--vg--1-ubuntu--lv  1.5T   49G  1.4T   4% /

# Verify LVM configuration
sudo lvdisplay /dev/ubuntu-vg-1/ubuntu-lv | grep "LV Size"
# Should show: LV Size   1.46 TiB (or similar)
```

---

## Post-Resize Steps

### Step 1: Restart Docker Services

```bash
# Start all containers
docker start $(docker ps -aq)

# Wait for services to initialize
sleep 30

# Check container status
docker ps

# Verify critical services
docker ps --filter "name=sabnzbd" --filter "name=plex" --filter "name=radarr" --filter "name=sonarr"
```

### Step 2: Exit Troubleshooting Mode

```bash
# Restart HealthWatch
docker start healthwatch

# Verify HealthWatch is running
docker ps --filter "name=healthwatch"
```

### Step 3: Verify Everything Works

```bash
# Check SABnzbd can write to downloads
docker exec sabnzbd touch /downloads/usenet/incomplete/test-file
docker exec sabnzbd ls -la /downloads/usenet/incomplete/test-file
docker exec sabnzbd rm /downloads/usenet/incomplete/test-file

# Check disk usage monitoring
/docker/mediaserver/cleanup-incomplete.sh

# View logs
tail -20 /docker/mediaserver/logs/cleanup-incomplete.log
```

---

## Updated Storage Allocation

### Before Resize
```
Root Partition: 98GB
├── System: ~50GB
├── Free: 45GB
└── Risk: High (could fill during large downloads)
```

### After Resize
```
Root Partition: 1.5TB
├── System: ~50GB
├── SSD Cache for downloads: 200-300GB target
├── Docker images/volumes: ~50GB
└── Free buffer: ~1.1TB

SSD Cache Breakdown:
├── Plex transcoding: 30-50GB
├── SABnzbd incomplete: 100-200GB (multiple 60GB 4K movies)
└── (Optional) Deluge seeding: 50-100GB
```

---

## Troubleshooting

### If lvextend Fails with "Insufficient free space"

```bash
# Check actual free space
sudo vgdisplay ubuntu-vg-1 | grep "Free"

# If less than expected, use percentage instead
sudo lvextend -l +90%FREE /dev/ubuntu-vg-1/ubuntu-lv
```

### If resize2fs Fails

```bash
# Check filesystem for errors first
sudo e2fsck -f /dev/ubuntu-vg-1/ubuntu-lv

# Then retry resize
sudo resize2fs /dev/ubuntu-vg-1/ubuntu-lv
```

### If Containers Won't Start After Resize

```bash
# Check Docker daemon
sudo systemctl status docker

# Restart Docker daemon if needed
sudo systemctl restart docker

# Check disk space
df -h /

# Check container logs
docker logs <container-name>
```

---

## Updated Cleanup Configuration

With 1.5TB space, we can adjust cleanup to be less aggressive:

### Current Cleanup Settings (Can Be Relaxed)

```bash
# Edit cleanup script if desired
nano /docker/mediaserver/cleanup-incomplete.sh

# Current settings:
# - Runs every 6 hours
# - Removes files older than 2 days
# - Emergency cleanup at 75% usage

# Recommended new settings for 1.5TB:
# - Runs every 12 hours (or keep 6 hours)
# - Removes files older than 5 days (more time for failed downloads to retry)
# - Emergency cleanup at 80% usage (1.2TB used)
```

### Optional: Relax Cleanup Frequency

```bash
# Change cron to run every 12 hours instead of 6
crontab -e

# Change:
# 0 */6 * * * /docker/mediaserver/cleanup-incomplete.sh
# To:
# 0 */12 * * * /docker/mediaserver/cleanup-incomplete.sh
```

---

## Risk Assessment

### Low Risk
- ✅ LVM resize is non-destructive
- ✅ Can be done online (filesystem mounted)
- ✅ No data loss if done correctly
- ✅ Can be reversed if needed (shrinking is harder, but expanding is safe)

### Medium Risk
- ⚠️ Docker containers must be stopped (5-10 minutes downtime)
- ⚠️ Requires sudo access
- ⚠️ If interrupted, filesystem might need fsck

### Mitigation
- ✅ Backup created before resize
- ✅ All services stopped gracefully
- ✅ Commands are well-tested and safe
- ✅ Can restore from backup if needed

---

## Rollback Procedure (If Needed)

**Note:** Shrinking filesystems is dangerous. Only do this if absolutely necessary.

```bash
# DON'T shrink unless absolutely required
# If you must rollback, restore from backup instead:

# 1. Stop Docker
docker stop $(docker ps -q)

# 2. Restore backup
sudo tar -xzf /data/backups/docker-configs-YYYYMMDD.tar.gz -C /

# 3. Restart Docker
docker start $(docker ps -aq)
```

---

## Verification Checklist

After resize, verify:

- [ ] Root partition shows ~1.5TB total size
- [ ] Free space shows ~1.4TB available
- [ ] All Docker containers started successfully
- [ ] SABnzbd can write to /downloads/usenet/incomplete
- [ ] Plex can transcode to /transcode
- [ ] HealthWatch is monitoring services
- [ ] Cleanup script runs without errors
- [ ] No filesystem errors in dmesg/logs

---

## Expected Results

**Before:**
```
Filesystem                            Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg--1-ubuntu--lv   98G   49G   45G  53% /
```

**After:**
```
Filesystem                            Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg--1-ubuntu--lv  1.5T   49G  1.4T   4% /
```

**Benefits:**
- 15x more space for downloads
- Can handle 20+ simultaneous 60GB 4K downloads
- No risk of root partition filling up
- Better utilization of existing 1.8TB NVMe
- System will never freeze due to disk space again

---

## Post-Resize Monitoring

For the first week after resize, monitor:

```bash
# Daily disk usage check
df -h / | tail -1

# Check for filesystem errors
dmesg | grep -i error

# Monitor download usage
du -sh /home/username/ssd-cache/downloads

# Check cleanup logs
tail -50 /docker/mediaserver/logs/cleanup-incomplete.log
```

---

## Documentation Updates

After successful resize, update:

- [ ] `/docker/mediaserver/STORAGE_OPTIMIZATION.md` - Update partition sizes
- [ ] `/docker/mediaserver/STORAGE_QUICK_REFERENCE.md` - Update storage allocation
- [ ] `/docker/mediaserver/CHANGELOG.md` - Add v1.7.3 entry for partition resize
- [ ] This file - Add completion date and actual results

---

**Resize Completion:**

- Date completed: _________________
- Final root partition size: _________________
- Final free space: _________________
- Any issues encountered: _________________
- Services verified working: _________________

---

**Document Version:** 1.0
**Last Updated:** 2025-11-01
**Status:** Ready to execute
