#!/bin/bash
# Automated Root Partition Resize Script
# Expands ubuntu-vg-1/ubuntu-lv to use maximum available NVMe space

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Progress tracking
TOTAL_STEPS=8
START_TIME=$(date +%s)

# Function to show progress
show_progress() {
    local step=$1
    local total=$TOTAL_STEPS
    local percent=$((step * 100 / total))
    local elapsed=$(($(date +%s) - START_TIME))

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} Progress: [$step/$total] ${percent}% complete"
    echo -e "${CYAN}║${NC} Elapsed time: ${elapsed} seconds"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
}

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Root Partition Resize Script          ║${NC}"
echo -e "${BLUE}║  Target: Expand to ~1.5TB              ║${NC}"
echo -e "${BLUE}║  Estimated time: 10-15 minutes         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  This will cause 10-15 minutes of service downtime${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Step 1: Show current state
show_progress 1
echo -e "${YELLOW}Step 1/8: Current Partition State${NC}"
echo -e "${CYAN}ETA: <1 minute${NC}"
echo "----------------------------------------"
df -h / | grep -E "Filesystem|mapper"
echo ""
vgdisplay ubuntu-vg-1 | grep -E "VG Name|VG Size|Free"
echo ""
lvdisplay /dev/ubuntu-vg-1/ubuntu-lv | grep -E "LV Name|LV Size"
echo ""

read -p "Continue with backup? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Step 2: Create backup
show_progress 2
echo -e "${YELLOW}Step 2/8: Creating Backup${NC}"
echo -e "${CYAN}ETA: 1-2 minutes${NC}"
echo "----------------------------------------"
BACKUP_FILE="/data/backups/docker-configs-$(date +%Y%m%d-%H%M%S).tar.gz"
mkdir -p /data/backups

echo "Backing up to: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" \
    /docker/mediaserver \
    --exclude=/docker/mediaserver/*/Cache \
    --exclude=/docker/mediaserver/*/logs \
    2>/dev/null || echo "Warning: Some files skipped"

if [ -f "$BACKUP_FILE" ]; then
    echo -e "${GREEN}✓ Backup created: $(ls -lh $BACKUP_FILE | awk '{print $5}')${NC}"
else
    echo -e "${RED}ERROR: Backup failed${NC}"
    exit 1
fi
echo ""

read -p "Continue with stopping containers? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Step 3: Stop services
show_progress 3
echo -e "${YELLOW}Step 3/8: Stopping Docker Services${NC}"
echo -e "${CYAN}ETA: 1 minute (includes 30s graceful shutdown)${NC}"
echo "----------------------------------------"
echo "Stopping HealthWatch..."
docker stop healthwatch 2>/dev/null || echo "HealthWatch already stopped"

echo "Stopping all containers..."
docker stop $(docker ps -q) 2>/dev/null || echo "No running containers"

echo "Waiting 30 seconds for graceful shutdown..."
sleep 30

RUNNING=$(docker ps -q | wc -l)
if [ "$RUNNING" -gt 0 ]; then
    echo -e "${RED}WARNING: $RUNNING containers still running${NC}"
    docker ps
    read -p "Force continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted. Restarting containers..."
        docker start $(docker ps -aq)
        exit 0
    fi
fi
echo -e "${GREEN}✓ All containers stopped${NC}"
echo ""

read -p "Continue with LVM resize? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted. Restarting containers..."
    docker start $(docker ps -aq)
    exit 0
fi

# Step 4: Extend logical volume
show_progress 4
echo -e "${YELLOW}Step 4/8: Extending Logical Volume${NC}"
echo -e "${CYAN}ETA: <10 seconds${NC}"
echo "----------------------------------------"
echo "Using 100% of free space in volume group..."
lvextend -l +100%FREE /dev/ubuntu-vg-1/ubuntu-lv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Logical volume extended${NC}"
else
    echo -e "${RED}ERROR: LVM extend failed${NC}"
    echo "Restarting containers..."
    docker start $(docker ps -aq)
    exit 1
fi
echo ""

# Step 5: Resize filesystem
show_progress 5
echo -e "${YELLOW}Step 5/8: Resizing Filesystem (LONGEST STEP)${NC}"
echo -e "${CYAN}ETA: 5-10 minutes - Please wait, this is normal...${NC}"
echo "----------------------------------------"
echo "Resizing ext4 filesystem (this may take a few minutes)..."
resize2fs /dev/ubuntu-vg-1/ubuntu-lv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Filesystem resized${NC}"
else
    echo -e "${RED}ERROR: Filesystem resize failed${NC}"
    echo "Restarting containers..."
    docker start $(docker ps -aq)
    exit 1
fi
echo ""

# Step 6: Verify new size
show_progress 6
echo -e "${YELLOW}Step 6/8: Verifying New Size${NC}"
echo -e "${CYAN}ETA: <10 seconds${NC}"
echo "----------------------------------------"
df -h / | grep -E "Filesystem|mapper"
echo ""
lvdisplay /dev/ubuntu-vg-1/ubuntu-lv | grep "LV Size"
echo ""

# Step 7: Restart services (CORRECT ORDER for Gluetun dependencies)
show_progress 7
echo -e "${YELLOW}Step 7/8: Restarting Docker Services${NC}"
echo -e "${CYAN}ETA: 2-3 minutes (Gluetun must start first, then SABnzbd/Deluge)${NC}"
echo "----------------------------------------"

echo "Starting Gluetun (VPN) first..."
docker compose up -d gluetun

echo "Waiting 60 seconds for VPN to establish..."
sleep 60

echo "Starting VPN-dependent services (SABnzbd, Deluge)..."
docker compose up -d sabnzbd deluge

echo "Waiting 10 seconds..."
sleep 10

echo "Starting all other services..."
docker compose up -d

echo "Waiting 30 seconds for services to initialize..."
sleep 30

echo ""
echo "Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | head -15
echo ""

# Step 8: Final verification
show_progress 8
echo -e "${YELLOW}Step 8/8: Final Verification${NC}"
echo -e "${CYAN}ETA: <1 minute${NC}"
echo "----------------------------------------"
echo "Testing SABnzbd write access..."
docker exec sabnzbd touch /downloads/usenet/incomplete/test-resize 2>/dev/null && \
docker exec sabnzbd rm /downloads/usenet/incomplete/test-resize 2>/dev/null && \
echo -e "${GREEN}✓ SABnzbd can write to downloads${NC}" || \
echo -e "${RED}✗ SABnzbd write test failed${NC}"

echo ""
echo "Running cleanup script test..."
/docker/mediaserver/cleanup-incomplete.sh
echo -e "${GREEN}✓ Cleanup script executed${NC}"

TOTAL_TIME=$(($(date +%s) - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Resize Complete!                ║${NC}"
echo -e "${GREEN}║  Total time: ${MINUTES}m ${SECONDS}s                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Summary:${NC}"
df -h / | tail -1 | awk '{print "  Root partition: " $2 " total, " $4 " available (" $5 " used)"}'
echo ""
echo "Next steps:"
echo "  1. Monitor disk usage: df -h /"
echo "  2. Check logs: tail -50 /docker/mediaserver/logs/cleanup-incomplete.log"
echo "  3. Verify services: docker ps"
echo "  4. Test a download in SABnzbd"
echo ""
echo "Backup location: $BACKUP_FILE"
echo ""
