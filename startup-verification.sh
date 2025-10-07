#!/bin/bash
# Startup Verification Script
# Verifies media server network configuration after reboots/restarts
# Author: Media Server Management System

set -euo pipefail

# Configuration
COMPOSE_PATH="/docker/mediaserver"
LOG_FILE="./startup-verification.log"
EXTERNAL_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "UNKNOWN")
EXPECTED_SERVICES=("gluetun" "sabnzbd" "deluge")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        *)       echo "[$level] $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to check if container is running
is_container_running() {
    local container=$1
    docker ps --filter "name=$container" --filter "status=running" --quiet | grep -q .
}

# Function to check if container is healthy
is_container_healthy() {
    local container=$1
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    [[ "$health_status" == "healthy" ]]
}

# Function to check port binding
check_port_binding() {
    local container=$1
    local port=$2
    local expected_binding=$3

    local actual_binding
    actual_binding=$(docker port "$container" "$port" 2>/dev/null | head -1 || echo "NOT_BOUND")

    if [[ "$actual_binding" == *"$expected_binding"* ]]; then
        log "INFO" "✅ $container:$port correctly bound to $expected_binding"
        return 0
    else
        log "ERROR" "❌ $container:$port bound to '$actual_binding', expected '$expected_binding'"
        return 1
    fi
}

# Function to test external connectivity
test_external_access() {
    local service=$1
    local port=$2
    local timeout=${3:-10}

    if [[ "$EXTERNAL_IP" == "UNKNOWN" ]]; then
        log "WARN" "⚠️  Cannot test external access - unknown external IP"
        return 1
    fi

    local url="http://$EXTERNAL_IP:$port"

    if curl -I --connect-timeout "$timeout" --max-time "$timeout" "$url" >/dev/null 2>&1; then
        log "INFO" "✅ External access working: $url"
        return 0
    else
        log "ERROR" "❌ External access failed: $url"
        return 1
    fi
}

# Function to test local network access
test_local_access() {
    local service=$1
    local port=$2
    local interface=$3
    local timeout=${4:-5}

    local url="http://$interface:$port"

    if curl -I --connect-timeout "$timeout" --max-time "$timeout" "$url" >/dev/null 2>&1; then
        log "INFO" "✅ Local access working: $url"
        return 0
    else
        log "ERROR" "❌ Local access failed: $url"
        return 1
    fi
}

# Function to check VPN status
check_vpn_status() {
    log "INFO" "Checking VPN status..."

    if ! is_container_running "gluetun"; then
        log "ERROR" "❌ Gluetun container is not running"
        return 1
    fi

    if is_container_healthy "gluetun"; then
        log "INFO" "✅ Gluetun is healthy"
    else
        log "WARN" "⚠️  Gluetun health check not available or unhealthy"
    fi

    # Check VPN IP
    local vpn_ip
    vpn_ip=$(docker exec gluetun wget -qO- --timeout=10 ifconfig.me 2>/dev/null || echo "UNKNOWN")

    if [[ "$vpn_ip" != "UNKNOWN" && "$vpn_ip" != "$EXTERNAL_IP" ]]; then
        log "INFO" "✅ VPN is active (VPN IP: $vpn_ip, Server IP: $EXTERNAL_IP)"
    else
        log "WARN" "⚠️  VPN status unclear (VPN IP: $vpn_ip, Server IP: $EXTERNAL_IP)"
    fi
}

# Function to check download client services
check_download_clients() {
    log "INFO" "Checking download client services..."

    local all_good=true

    # Check SABnzbd
    if is_container_running "sabnzbd"; then
        log "INFO" "✅ SABnzbd container is running"
        check_port_binding "gluetun" "8080/tcp" "0.0.0.0:8080" || all_good=false
        test_local_access "sabnzbd" "8080" "localhost" || all_good=false
        test_external_access "sabnzbd" "8080" || all_good=false
    else
        log "ERROR" "❌ SABnzbd container is not running"
        all_good=false
    fi

    # Check Deluge
    if is_container_running "deluge"; then
        log "INFO" "✅ Deluge container is running"
        check_port_binding "gluetun" "8112/tcp" "0.0.0.0:8112" || all_good=false
        test_local_access "deluge" "8112" "localhost" || all_good=false
        test_external_access "deluge" "8112" || all_good=false
    else
        log "ERROR" "❌ Deluge container is not running"
        all_good=false
    fi

    return $([[ "$all_good" == true ]])
}

# Function to check network dependencies
check_network_dependencies() {
    log "INFO" "Checking network dependencies..."

    # Check if dependent services can reach external network through VPN
    local connectivity_ok=true

    for service in "sabnzbd" "deluge"; do
        if is_container_running "$service"; then
            if docker exec "$service" ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
                log "INFO" "✅ $service has external connectivity through VPN"
            else
                log "ERROR" "❌ $service cannot reach external network"
                connectivity_ok=false
            fi
        fi
    done

    return $([[ "$connectivity_ok" == true ]])
}

# Function to suggest fixes
suggest_fixes() {
    log "INFO" "Suggested fixes for common issues:"
    log "INFO" "  1. If services are not running: cd $COMPOSE_PATH && docker compose up -d"
    log "INFO" "  2. If VPN is unhealthy: cd $COMPOSE_PATH && ./vpn-restart-handler.sh restart-vpn"
    log "INFO" "  3. If external access fails: Check firewall and router port forwarding"
    log "INFO" "  4. If port bindings are wrong: Check docker-compose.yml port configuration"
    log "INFO" "  5. For network namespace issues: ./vpn-restart-handler.sh fix-namespaces"
}

# Main verification function
main() {
    cd "$COMPOSE_PATH"

    log "INFO" "=== Media Server Startup Verification ==="
    log "INFO" "External IP: $EXTERNAL_IP"
    log "INFO" "Timestamp: $(date)"
    log "INFO" ""

    local overall_status=true

    # Check VPN
    check_vpn_status || overall_status=false

    # Check download clients
    check_download_clients || overall_status=false

    # Check network dependencies
    check_network_dependencies || overall_status=false

    log "INFO" ""
    if [[ "$overall_status" == true ]]; then
        log "INFO" "🎉 All verification checks passed!"
        log "INFO" "✅ External access: http://$EXTERNAL_IP:8080 (SABnzbd)"
        log "INFO" "✅ External access: http://$EXTERNAL_IP:8112 (Deluge)"
    else
        log "ERROR" "❌ Some verification checks failed!"
        suggest_fixes
        exit 1
    fi
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Run main function
main "$@"