#!/bin/bash
# Troubleshooting Mode Helper Script
# Prevents false positive alerts during manual troubleshooting

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  HealthWatch Troubleshooting Mode${NC}"
    echo -e "${GREEN}========================================${NC}"
}

function check_healthwatch_status() {
    if docker ps --filter "name=healthwatch" --filter "status=running" | grep -q healthwatch; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

function enter_troubleshooting_mode() {
    print_header
    echo ""
    echo -e "${YELLOW}Entering troubleshooting mode...${NC}"
    echo ""

    if check_healthwatch_status; then
        echo "→ Stopping HealthWatch monitoring to prevent false alerts..."
        docker stop healthwatch
        echo -e "${GREEN}✓${NC} HealthWatch stopped"
    else
        echo -e "${YELLOW}⚠${NC} HealthWatch is already stopped"
    fi

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  TROUBLESHOOTING MODE ACTIVE${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "You can now safely:"
    echo "  • Restart services for troubleshooting"
    echo "  • Stop/start containers without alerts"
    echo "  • Test configuration changes"
    echo ""
    echo -e "${YELLOW}Remember to exit troubleshooting mode when done!${NC}"
    echo "Run: ./troubleshooting-mode.sh exit"
    echo ""
}

function exit_troubleshooting_mode() {
    print_header
    echo ""
    echo -e "${YELLOW}Exiting troubleshooting mode...${NC}"
    echo ""

    if ! check_healthwatch_status; then
        echo "→ Starting HealthWatch monitoring..."
        docker start healthwatch
        echo -e "${GREEN}✓${NC} HealthWatch started"

        # Wait for HealthWatch to initialize
        echo ""
        echo "Waiting for HealthWatch to initialize (this may take up to 10 minutes for all services to be ready)..."
        sleep 5

        # Show logs
        echo ""
        echo "HealthWatch startup logs:"
        docker logs healthwatch --tail 20
    else
        echo -e "${YELLOW}⚠${NC} HealthWatch is already running"
    fi

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  NORMAL MONITORING RESUMED${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "HealthWatch is now monitoring all services."
    echo "Alerts will be sent if any service goes down."
    echo ""
}

function show_status() {
    print_header
    echo ""

    if check_healthwatch_status; then
        echo -e "${GREEN}Status: MONITORING ACTIVE${NC}"
        echo ""
        echo "HealthWatch is running and monitoring services."
        echo "Run './troubleshooting-mode.sh enter' to disable alerts for maintenance."
    else
        echo -e "${YELLOW}Status: TROUBLESHOOTING MODE${NC}"
        echo ""
        echo "HealthWatch is stopped. No alerts will be sent."
        echo "Run './troubleshooting-mode.sh exit' to resume monitoring."
    fi

    echo ""
}

# Main script logic
case "${1:-}" in
    enter|start|on)
        enter_troubleshooting_mode
        ;;
    exit|stop|off|resume)
        exit_troubleshooting_mode
        ;;
    status|check)
        show_status
        ;;
    *)
        print_header
        echo ""
        echo "Usage: $0 {enter|exit|status}"
        echo ""
        echo "Commands:"
        echo "  enter   - Enter troubleshooting mode (stop HealthWatch)"
        echo "  exit    - Exit troubleshooting mode (start HealthWatch)"
        echo "  status  - Check current mode"
        echo ""
        echo "Examples:"
        echo "  $0 enter     # Before troubleshooting/maintenance"
        echo "  $0 exit      # After troubleshooting complete"
        echo "  $0 status    # Check if monitoring is active"
        echo ""
        exit 1
        ;;
esac
