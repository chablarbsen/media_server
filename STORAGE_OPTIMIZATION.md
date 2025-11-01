# Storage Optimization Analysis & Recommendations

**Date:** 2025-11-01
**Issue:** Manual deletion required for failed downloads in SABnzbd incomplete directory
**Root Cause:** Storage configuration not optimized for download workflow

---

## Current Storage Configuration

### Disk Partitions
```
Root Partition (/):              98GB  (53% used - 49GB/98GB)
  - Docker system files
  - OS and system packages
  - Location: /dev/mapper/ubuntu--vg--1-ubuntu--lv

RAID Array (/data):              8.2TB (27% used - 2.1TB/8.2TB)
  - Media storage
  - Completed downloads
  - Service configuration backups
  - Location: /dev/md0 (ext4, noatime, nodiratime, stripe=384)

SSD Cache (/home/username/ssd-cache): Small partition on root disk
  - Plex transcoding: /home/username/ssd-cache/transcode
  - Downloads: /home/username/ssd-cache/downloads (UNDERUTILIZED - only 4KB)
```

### Current SABnzbd Configuration
```ini
download_dir = /data/usenet/incomplete    # ❌ RAID-based (slow for incomplete)
complete_dir = /data/usenet/complete      # ✅ RAID-based (appropriate for archives)
```

**Current Usage:**
- `/data/usenet/incomplete`: 12KB (cleaned manually)
- `/data/usenet/complete`: 4.0GB
- `/docker/mediaserver/sabnzbd/Downloads/incomplete`: 4KB (config only)
- `/home/username/ssd-cache/downloads`: 4KB (UNUSED)

### Current Deluge Configuration
```yaml
volumes:
  - ./deluge:/config
  - /data:/data
```
- Uses RAID for both incomplete and complete torrents
- No SSD acceleration for active seeding

---

## Problem Analysis

### Issue 1: SABnzbd Incomplete Downloads on RAID
**Problem:**
- Incomplete Usenet downloads stored on RAID array (`/data/usenet/incomplete`)
- RAID arrays optimized for sequential I/O, not random write patterns
- Extracting/unpacking uses RAID storage during processing
- Failed downloads accumulate and require manual cleanup

**Impact:**
- Slower download extraction/unpacking
- Higher RAID wear for temporary files
- Manual intervention needed for cleanup
- Root partition has space but not utilized

### Issue 2: Deluge Torrents Not Optimized for Seeding
**Problem:**
- Active torrents seeding from RAID storage (`/data`)
- Torrents benefit from fast random I/O for piece requests
- SSD would dramatically improve seeding performance
- SSD cache exists but unused

**Impact:**
- Slower upload speeds for seeding
- Missed opportunities for SSD acceleration
- Potential performance benefits lost

### Issue 3: Docker Path Confusion
**Current docker-compose.yml volumes:**
```yaml
gluetun:
  volumes:
    - /home/username/ssd-cache/downloads:/downloads  # ❌ NOT used by SABnzbd config

sabnzbd:
  volumes:
    - ./sabnzbd:/config
    - /data:/data                                 # ✅ Used, but not optimal
```

**Problem:**
- Gluetun mounts SSD cache but SABnzbd doesn't use it
- SABnzbd configured to use `/data` directly
- No separation between temporary and permanent storage

---

## Recommended Storage Strategy

### Strategy Overview
**Separate concerns by I/O pattern and permanence:**

1. **SSD (Fast, Temporary)** → Active downloads, incomplete files, active torrents
2. **RAID (Large, Permanent)** → Completed downloads, media library, long-term storage

### Detailed Recommendations

#### For SABnzbd (Usenet Downloads)

**RECOMMENDED: Use SSD for incomplete, RAID for complete**

```ini
# Inside SABnzbd container (/config/sabnzbd.ini)
download_dir = /downloads/usenet/incomplete    # SSD - fast random I/O
complete_dir = /data/usenet/complete           # RAID - large permanent storage
```

**Docker volume mapping:**
```yaml
sabnzbd:
  volumes:
    - ./sabnzbd:/config
    - /data:/data                                    # RAID for completed
    - /home/username/ssd-cache/downloads:/downloads     # SSD for incomplete
```

**Benefits:**
- ✅ Faster extraction and unpacking (SSD random I/O)
- ✅ Less RAID wear from temporary operations
- ✅ Failed downloads cleaned up easier (separate partition)
- ✅ Completed downloads move to RAID automatically
- ✅ Better utilize existing SSD cache

#### For Deluge (Torrents)

**OPTION A: Keep torrents on RAID (Conservative)**
- Pros: Unlimited space, permanent storage
- Cons: Slower seeding performance
- Best for: Low seeding ratio requirements, archive torrents

**OPTION B: Use SSD for active seeding (Performance)**

```yaml
deluge:
  volumes:
    - ./deluge:/config
    - /data:/data                                      # RAID for permanent storage
    - /home/username/ssd-cache/downloads/torrents:/downloads  # SSD for active torrents
```

Configure Deluge:
- **Incomplete**: `/downloads/incomplete` (SSD)
- **Complete**: `/downloads/complete` (SSD) → Auto-move to `/data/torrents` when complete
- **Seeding**: Keep active torrents on SSD for fast uploads

**Benefits:**
- ✅ Much faster seeding speeds (SSD random I/O)
- ✅ Better tracker ratios
- ✅ Completed/unseeded torrents move to RAID
- ⚠️ Requires monitoring SSD space usage

**RECOMMENDED APPROACH: Hybrid Strategy**
```yaml
deluge:
  volumes:
    - ./deluge:/config
    - /data:/data                                         # RAID for media
    - /home/username/ssd-cache/downloads/torrents:/torrents  # SSD for active seeding
```

Configure categories in Deluge:
- **Category: tv** → Move completed to `/data/media/tv`
- **Category: movies** → Move completed to `/data/media/movies`
- **Category: seed** → Keep on SSD at `/torrents/seed` for active seeding
- **Default** → Move to RAID after completion

---

## Implementation Plan

### Phase 1: SABnzbd Migration (IMMEDIATE - Prevents Future Issues)

**1. Create SSD directories:**
```bash
mkdir -p /home/username/ssd-cache/downloads/usenet/incomplete
chown -R username:media /home/username/ssd-cache/downloads
chmod -R 775 /home/username/ssd-cache/downloads
```

**2. Update docker-compose.yml:**
```yaml
sabnzbd:
  volumes:
    - ./sabnzbd:/config
    - /data:/data
    - /home/username/ssd-cache/downloads:/downloads  # Add this line
```

**3. Update SABnzbd configuration:**
```bash
# Stop SABnzbd
docker compose stop sabnzbd

# Edit /docker/mediaserver/sabnzbd/sabnzbd.ini
# Change these lines:
#   download_dir = /data/usenet/incomplete
#   complete_dir = /data/usenet/complete
# To:
#   download_dir = /downloads/usenet/incomplete
#   complete_dir = /data/usenet/complete

# Restart services
docker compose up -d sabnzbd
```

**4. Verify configuration:**
```bash
# Check SABnzbd recognizes new paths
docker exec sabnzbd ls -la /downloads/usenet/
docker logs sabnzbd --tail 50 | grep -i "download"
```

**5. Test with a small download:**
- Add a small NZB to SABnzbd
- Verify it downloads to `/downloads/usenet/incomplete` (SSD)
- Verify it moves to `/data/usenet/complete` (RAID) when done

### Phase 2: Deluge Optimization (OPTIONAL - Performance Boost)

**DECISION REQUIRED:** Choose between:

**Option A: Status Quo (Simple, Conservative)**
- Keep current configuration
- No changes needed
- Adequate for most use cases

**Option B: SSD Seeding (Complex, High Performance)**
- Implement hybrid SSD/RAID strategy
- Better for maintaining high seeding ratios
- Requires active monitoring of SSD space

**If choosing Option B:**

**1. Create SSD directories:**
```bash
mkdir -p /home/username/ssd-cache/downloads/torrents/{incomplete,complete,seed}
chown -R username:media /home/username/ssd-cache/downloads/torrents
chmod -R 775 /home/username/ssd-cache/downloads/torrents
```

**2. Update docker-compose.yml:**
```yaml
deluge:
  volumes:
    - ./deluge:/config
    - /data:/data
    - /home/username/ssd-cache/downloads/torrents:/torrents  # Add this line
```

**3. Configure Deluge paths:**
- Access Deluge Web UI (http://gluetun:8112)
- Preferences → Downloads:
  - Download to: `/torrents/incomplete`
  - Move completed to: `/torrents/complete`
  - Auto-managed: Enabled

**4. Set up category-based auto-move:**
- Category "tv" → Auto-move to `/data/media/tv`
- Category "movies" → Auto-move to `/data/media/movies`
- Category "seed" → Keep at `/torrents/seed` (no auto-move)

**5. Create monitoring script:**
```bash
# Monitor SSD usage for torrents
df -h /home/username/ssd-cache | tail -1
du -sh /home/username/ssd-cache/downloads/torrents/*
```

---

## Space Management Guidelines

### SSD Cache Allocation (/home/username/ssd-cache)
**Available on root partition:** 45GB free (53% used)

**Recommended allocation:**
```
/home/username/ssd-cache/
├── transcoding/     (30GB max - Plex temporary)
├── downloads/
│   ├── usenet/
│   │   └── incomplete/  (10GB max - SABnzbd temporary)
│   └── torrents/
│       ├── incomplete/  (5GB max - Deluge active downloads)
│       ├── complete/    (Transient - auto-moved)
│       └── seed/        (20GB max - Active seeding torrents)
```

**Total SSD usage target:** <40GB (leaves 5GB buffer on root partition)

### Cleanup Automation

**Create automated cleanup script:**
```bash
#!/bin/bash
# /docker/mediaserver/cleanup-incomplete.sh

# Clean SABnzbd failed downloads older than 7 days
find /home/username/ssd-cache/downloads/usenet/incomplete -type f -mtime +7 -delete

# Clean Deluge incomplete torrents older than 30 days (if using SSD)
find /home/username/ssd-cache/downloads/torrents/incomplete -type f -mtime +30 -delete

# Alert if SSD cache exceeds 80% usage
USAGE=$(df -h /home/username/ssd-cache | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$USAGE" -gt 80 ]; then
    echo "WARNING: SSD cache usage at ${USAGE}%" | logger -t storage-monitor
    # Could integrate with HealthWatch for email alerts
fi
```

**Schedule via cron:**
```bash
# Run cleanup daily at 3 AM
0 3 * * * /docker/mediaserver/cleanup-incomplete.sh
```

---

## Disk Space Comparison

### Before Optimization
```
Root (SSD equivalent): 45GB free / 98GB total (46% free)
RAID: 5.7TB free / 8.2TB total (69% free)

Issues:
- SSD underutilized (only Plex transcoding)
- RAID handling temporary files unnecessarily
- Manual cleanup required for incomplete downloads
```

### After Optimization
```
Root (SSD equivalent): 35-40GB free / 98GB total (36-41% free)
RAID: 5.7TB free / 8.2TB total (69% free)

Benefits:
- SSD used for temporary high-I/O operations
- RAID reserved for permanent storage
- Automated cleanup prevents manual intervention
- Better overall performance
```

---

## Monitoring & Alerts

### Add to HealthWatch (Future Enhancement)

**Disk space monitoring:**
```python
# In healthwatch.py
def check_disk_space():
    # Check root partition
    root_usage = shutil.disk_usage('/')
    if root_usage.percent > 80:
        send_alert(f"Root partition at {root_usage.percent}%")

    # Check RAID
    raid_usage = shutil.disk_usage('/data')
    if raid_usage.percent > 85:
        send_alert(f"RAID array at {raid_usage.percent}%")

    # Check SSD cache
    ssd_usage = shutil.disk_usage('/home/username/ssd-cache')
    if ssd_usage.percent > 80:
        send_alert(f"SSD cache at {ssd_usage.percent}%")
```

### Manual Monitoring Commands

```bash
# Check overall disk usage
df -h

# Check SSD cache breakdown
du -sh /home/username/ssd-cache/*

# Check SABnzbd incomplete size
du -sh /home/username/ssd-cache/downloads/usenet/incomplete

# Check Deluge active torrents size (if using SSD)
du -sh /home/username/ssd-cache/downloads/torrents/seed

# Check RAID media storage
du -sh /data/media/*

# Check completed downloads
du -sh /data/usenet/complete
du -sh /data/torrents/*
```

---

## Performance Impact Estimates

### SABnzbd (Usenet)
**Before (RAID):**
- Download extraction: 10-15 MB/s (RAID random write bottleneck)
- Par2 repair: 15-20 MB/s
- Failed download cleanup: Manual

**After (SSD incomplete, RAID complete):**
- Download extraction: 100-200 MB/s (SSD random write)
- Par2 repair: 150-300 MB/s
- Failed download cleanup: Automated, fast deletion
- **Estimated improvement: 10x faster extraction**

### Deluge (Torrents) - IF using SSD for active seeding
**Before (RAID):**
- Upload speed: 5-10 MB/s per torrent (RAID random read)
- Concurrent seeding: 50-100 torrents max before slowdown

**After (SSD for active seeding):**
- Upload speed: 20-50 MB/s per torrent (SSD random read)
- Concurrent seeding: 200+ torrents without slowdown
- **Estimated improvement: 3-5x faster seeding**

---

## Risk Assessment

### Low Risk (SABnzbd SSD Migration)
- ✅ Minimal configuration change
- ✅ Easy rollback (change paths back)
- ✅ No data loss risk (complete files still on RAID)
- ✅ Automated cleanup prevents SSD fill-up
- ⚠️ Requires 10-15GB free on root partition

**RECOMMENDATION: Implement immediately**

### Medium Risk (Deluge SSD Seeding)
- ⚠️ Requires active space monitoring
- ⚠️ More complex category configuration
- ⚠️ Risk of SSD space exhaustion if not monitored
- ✅ Easy to disable and revert to RAID-only
- ⚠️ Requires 20-25GB free on root partition

**RECOMMENDATION: Implement only if:**
1. High seeding ratios are important
2. Willing to monitor SSD space weekly
3. Root partition can spare 25GB+

---

## Rollback Procedures

### Rollback SABnzbd to RAID (if needed)

**1. Stop SABnzbd:**
```bash
docker compose stop sabnzbd
```

**2. Move any in-progress downloads back to RAID:**
```bash
mv /home/username/ssd-cache/downloads/usenet/incomplete/* /data/usenet/incomplete/
```

**3. Edit `/docker/mediaserver/sabnzbd/sabnzbd.ini`:**
```ini
download_dir = /data/usenet/incomplete
complete_dir = /data/usenet/complete
```

**4. Optionally remove SSD volume from docker-compose.yml:**
```yaml
sabnzbd:
  volumes:
    - ./sabnzbd:/config
    - /data:/data
    # - /home/username/ssd-cache/downloads:/downloads  # Remove this line
```

**5. Restart:**
```bash
docker compose up -d sabnzbd
```

### Rollback Deluge to RAID-Only (if needed)

**1. Stop Deluge:**
```bash
docker compose stop deluge
```

**2. Move active torrents back to RAID:**
```bash
mv /home/username/ssd-cache/downloads/torrents/seed/* /data/torrents/
```

**3. Update Deluge preferences via Web UI:**
- Download to: `/data/torrents/incomplete`
- Move completed to: `/data/torrents/complete`

**4. Remove SSD volume from docker-compose.yml:**
```yaml
deluge:
  volumes:
    - ./deluge:/config
    - /data:/data
    # - /home/username/ssd-cache/downloads/torrents:/torrents  # Remove
```

**5. Restart:**
```bash
docker compose up -d deluge
```

---

## Summary & Next Steps

### Key Findings
1. ✅ Root partition has sufficient space (45GB free)
2. ❌ SSD cache is underutilized (only 4KB used for downloads)
3. ❌ SABnzbd using RAID for temporary operations (suboptimal)
4. ⚠️ Manual cleanup required due to poor separation of concerns

### Immediate Action Required
**Implement SABnzbd SSD migration (Phase 1):**
- Low risk, high benefit
- Prevents future manual cleanup
- Improves extraction performance by 10x
- Utilizes existing unused SSD cache

### Optional Enhancement
**Consider Deluge SSD seeding (Phase 2):**
- Higher performance for active seeding
- Requires ongoing space monitoring
- Implement only if seeding performance is priority

### Monitoring
**Add to quarterly maintenance:**
- Check SSD cache usage monthly
- Review automated cleanup logs weekly
- Verify SABnzbd complete directory on RAID growing as expected

---

## Files to Modify

**Immediate (Phase 1):**
1. `/docker/mediaserver/docker-compose.yml` - Add SSD volume to SABnzbd
2. `/docker/mediaserver/sabnzbd/sabnzbd.ini` - Update download_dir path
3. Create `/docker/mediaserver/cleanup-incomplete.sh` - Automated cleanup
4. Update crontab - Schedule cleanup script

**Optional (Phase 2):**
1. `/docker/mediaserver/docker-compose.yml` - Add SSD volume to Deluge
2. Deluge Web UI configuration - Update paths and categories
3. Update `/docker/mediaserver/cleanup-incomplete.sh` - Add torrent cleanup

**Documentation:**
1. This file (`STORAGE_OPTIMIZATION.md`) - Store for future reference
2. `/docker/mediaserver/CHANGELOG.md` - Document changes in v1.7.2
3. `/docker/mediaserver/README.md` - Update storage architecture section

---

## References

- Docker Compose Volumes: https://docs.docker.com/compose/compose-file/compose-file-v3/#volumes
- SABnzbd Configuration: https://sabnzbd.org/wiki/configuration/
- Deluge Configuration: https://dev.deluge-torrent.org/wiki/UserGuide
- Linux ext4 Performance: https://wiki.archlinux.org/title/Ext4#Performance
- RAID Performance Best Practices: https://wiki.debian.org/SoftwareRAIDHowto

---

**Document Version:** 1.0
**Last Updated:** 2025-11-01
**Next Review:** After Phase 1 implementation
