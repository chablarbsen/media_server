#!/bin/bash
# Database Health Monitor for Sonarr and Radarr
# Checks database integrity and creates backups
# Run this via cron every 6 hours

set -euo pipefail

LOG_FILE="/docker/mediaserver/logs/db-health-monitor.log"
BACKUP_DIR="/docker/mediaserver/backups/automated"
ALERT_FILE="/docker/mediaserver/logs/db-corruption-alert.log"
MAX_BACKUPS=7  # Keep 7 days of backups

# Services to monitor
SERVICES=("sonarr" "radarr")

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running as correct user
if [ "$EUID" -eq 0 ]; then
    log "ERROR: Do not run this script as root"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to check database integrity
check_database() {
    local db_path="$1"
    local service_name="$2"

    if [ ! -f "$db_path" ]; then
        log "WARNING: Database not found: $db_path"
        return 1
    fi

    # Check with Python sqlite3
    python3 -c "
import sqlite3
import sys

try:
    conn = sqlite3.connect('$db_path')
    cursor = conn.cursor()
    cursor.execute('PRAGMA integrity_check;')
    result = cursor.fetchone()[0]
    conn.close()

    if result == 'ok':
        print('OK')
        sys.exit(0)
    else:
        print('CORRUPTED')
        sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
"
    return $?
}

# Function to create backup
create_backup() {
    local db_path="$1"
    local service_name="$2"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="${service_name}_${timestamp}.db"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    # Use SQLite backup command for online backup
    python3 -c "
import sqlite3
import sys

try:
    # Connect to source database
    source = sqlite3.connect('$db_path')

    # Connect to backup database
    backup = sqlite3.connect('$backup_path')

    # Perform online backup
    source.backup(backup)

    # Close connections
    backup.close()
    source.close()

    print('Backup created: $backup_path')
    sys.exit(0)
except Exception as e:
    print(f'Backup failed: {e}')
    sys.exit(1)
" >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        log "SUCCESS: Created backup for $service_name at $backup_path"
        return 0
    else
        log "ERROR: Failed to create backup for $service_name"
        return 1
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    local service_name="$1"

    # Keep only the last MAX_BACKUPS files for each service
    find "$BACKUP_DIR" -name "${service_name}_*.db" -type f 2>/dev/null | sort -r | tail -n +$((MAX_BACKUPS + 1)) | while read -r old_backup; do
        log "Removing old backup: $old_backup"
        rm -f "$old_backup"
    done
}

# Function to get WAL file size
check_wal_size() {
    local db_path="$1"
    local service_name="$2"
    local wal_path="${db_path}-wal"

    if [ -f "$wal_path" ]; then
        local wal_size
        wal_size=$(stat -c "%s" "$wal_path" 2>/dev/null) || wal_size=$(stat -f "%z" "$wal_path" 2>/dev/null) || wal_size=0
        local wal_size_mb=$((wal_size / 1024 / 1024))

        if [ "$wal_size_mb" -gt 100 ]; then
            log "WARNING: $service_name WAL file is large: ${wal_size_mb}MB - Consider checkpoint"
        else
            log "INFO: $service_name WAL size: ${wal_size_mb}MB"
        fi
    fi
}

# Main monitoring loop
log "===== Starting database health check ====="

for service in "${SERVICES[@]}"; do
    log "Checking $service..."

    DB_PATH="/docker/mediaserver/${service}/${service}.db"

    # Check if service is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        log "WARNING: $service container is not running - skipping"
        continue
    fi

    # Check database integrity
    if check_database "$DB_PATH" "$service"; then
        log "SUCCESS: $service database integrity OK"

        # Create backup
        create_backup "$DB_PATH" "$service"

        # Check WAL file size
        check_wal_size "$DB_PATH" "$service"

        # Cleanup old backups
        cleanup_old_backups "$service"
    else
        log "CRITICAL: $service database corruption detected!"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CRITICAL: $service database corruption detected at $DB_PATH" >> "$ALERT_FILE"

        # Try to restore from latest backup
        LATEST_BACKUP=$(find "$BACKUP_DIR" -name "${service}_*.db" -type f | sort -r | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            log "ALERT: Found corruption - latest backup available: $LATEST_BACKUP"
            log "Manual intervention required - run: docker stop $service && cp $LATEST_BACKUP $DB_PATH && docker start $service"
        else
            log "ALERT: No backup available for $service - manual recovery required"
        fi
    fi

    log ""
done

log "===== Database health check complete ====="
