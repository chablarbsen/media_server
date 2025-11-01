#!/bin/bash
# Automated cleanup script for incomplete/failed downloads
# Created: 2025-11-01
# Purpose: Prevent SSD cache overflow and remove stale failed downloads

LOG_FILE="/docker/mediaserver/logs/cleanup-incomplete.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log directory exists
mkdir -p /docker/mediaserver/logs

echo "[$TIMESTAMP] Starting cleanup-incomplete.sh" >> "$LOG_FILE"

# Function to log with timestamp
log() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# Function to check disk usage and log
check_disk_usage() {
    local mount_point=$1
    local name=$2
    local usage=$(df -h "$mount_point" | tail -1 | awk '{print $5}' | sed 's/%//')
    log "Disk usage for $name: ${usage}%"
    echo "$usage"
}

# Check initial disk usage
log "=== Disk Usage Before Cleanup ==="
root_usage=$(check_disk_usage "/" "Root partition")
raid_usage=$(check_disk_usage "/data" "RAID array")

if [ -d "/home/chab/ssd-cache" ]; then
    ssd_usage=$(check_disk_usage "/home/chab/ssd-cache" "SSD cache")
else
    log "SSD cache directory not found"
    ssd_usage=0
fi

# Clean SABnzbd failed/incomplete downloads older than 2 days (aggressive to prevent root partition fill)
if [ -d "/home/chab/ssd-cache/downloads/usenet/incomplete" ]; then
    log "Cleaning SABnzbd incomplete downloads older than 2 days..."

    # Find and count files before deletion
    old_files=$(find /home/chab/ssd-cache/downloads/usenet/incomplete -type f -mtime +2 2>/dev/null | wc -l)

    if [ "$old_files" -gt 0 ]; then
        # Calculate size before deletion
        size_before=$(du -sh /home/chab/ssd-cache/downloads/usenet/incomplete 2>/dev/null | awk '{print $1}')

        # Delete files
        find /home/chab/ssd-cache/downloads/usenet/incomplete -type f -mtime +2 -delete 2>/dev/null

        # Calculate size after deletion
        size_after=$(du -sh /home/chab/ssd-cache/downloads/usenet/incomplete 2>/dev/null | awk '{print $1}')

        log "Removed $old_files files from SABnzbd incomplete (was: $size_before, now: $size_after)"
    else
        log "No old files found in SABnzbd incomplete directory"
    fi

    # Remove empty directories
    find /home/chab/ssd-cache/downloads/usenet/incomplete -type d -empty -delete 2>/dev/null
else
    log "SABnzbd incomplete directory not found at /home/chab/ssd-cache/downloads/usenet/incomplete"
fi

# Clean Deluge incomplete torrents older than 30 days (if using SSD)
if [ -d "/home/chab/ssd-cache/downloads/torrents/incomplete" ]; then
    log "Cleaning Deluge incomplete torrents older than 30 days..."

    old_files=$(find /home/chab/ssd-cache/downloads/torrents/incomplete -type f -mtime +30 2>/dev/null | wc -l)

    if [ "$old_files" -gt 0 ]; then
        size_before=$(du -sh /home/chab/ssd-cache/downloads/torrents/incomplete 2>/dev/null | awk '{print $1}')
        find /home/chab/ssd-cache/downloads/torrents/incomplete -type f -mtime +30 -delete 2>/dev/null
        size_after=$(du -sh /home/chab/ssd-cache/downloads/torrents/incomplete 2>/dev/null | awk '{print $1}')
        log "Removed $old_files files from Deluge incomplete (was: $size_before, now: $size_after)"
    else
        log "No old files found in Deluge incomplete directory"
    fi

    find /home/chab/ssd-cache/downloads/torrents/incomplete -type d -empty -delete 2>/dev/null
else
    log "Deluge incomplete directory not found (SSD optimization not enabled)"
fi

# Check disk usage after cleanup
log "=== Disk Usage After Cleanup ==="
root_usage_after=$(check_disk_usage "/" "Root partition")
raid_usage_after=$(check_disk_usage "/data" "RAID array")

if [ -d "/home/chab/ssd-cache" ]; then
    ssd_usage_after=$(check_disk_usage "/home/chab/ssd-cache" "SSD cache")
else
    ssd_usage_after=0
fi

# Alert if SSD cache exceeds 80% usage
if [ "$ssd_usage_after" -gt 80 ]; then
    log "WARNING: SSD cache usage at ${ssd_usage_after}% (threshold: 80%)"
    # Log to system logger for potential integration with monitoring
    logger -t storage-monitor "WARNING: SSD cache usage at ${ssd_usage_after}%"

    # Optional: Send email alert via HealthWatch API (if available)
    # curl -X POST http://localhost:8888/api/alert \
    #   -H "Content-Type: application/json" \
    #   -d '{"service": "storage", "message": "SSD cache at '"$ssd_usage_after"'%"}'
fi

# Alert if root partition exceeds 85% usage
if [ "$root_usage_after" -gt 85 ]; then
    log "WARNING: Root partition at ${root_usage_after}% (threshold: 85%)"
    logger -t storage-monitor "WARNING: Root partition at ${root_usage_after}%"
fi

# EMERGENCY: If root partition exceeds 75%, force immediate cleanup of ALL incomplete downloads
if [ "$root_usage_after" -gt 75 ]; then
    log "EMERGENCY: Root partition at ${root_usage_after}% - forcing immediate cleanup of all incomplete downloads"

    # Remove ALL incomplete downloads regardless of age
    if [ -d "/home/chab/ssd-cache/downloads/usenet/incomplete" ]; then
        emergency_files=$(find /home/chab/ssd-cache/downloads/usenet/incomplete -type f 2>/dev/null | wc -l)
        if [ "$emergency_files" -gt 0 ]; then
            log "Emergency cleanup: Removing $emergency_files incomplete download files"
            find /home/chab/ssd-cache/downloads/usenet/incomplete -type f -delete 2>/dev/null
            find /home/chab/ssd-cache/downloads/usenet/incomplete -type d -empty -delete 2>/dev/null
            logger -t storage-monitor "EMERGENCY: Cleared all incomplete downloads due to root partition at ${root_usage_after}%"
        fi
    fi

    # Also clean Docker build cache
    log "Emergency cleanup: Pruning Docker build cache"
    docker builder prune -f >> "$LOG_FILE" 2>&1
fi

# Alert if RAID array exceeds 90% usage
if [ "$raid_usage_after" -gt 90 ]; then
    log "WARNING: RAID array at ${raid_usage_after}% (threshold: 90%)"
    logger -t storage-monitor "WARNING: RAID array at ${raid_usage_after}%"
fi

log "=== Cleanup completed ==="
log ""

# Keep only last 30 days of logs
find /docker/mediaserver/logs -name "cleanup-incomplete.log" -type f -mtime +30 -delete 2>/dev/null

exit 0
