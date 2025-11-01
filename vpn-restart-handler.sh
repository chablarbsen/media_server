#!/bin/bash
# VPN Restart Handler
# Ensures proper restart sequence for VPN-dependent services
# Author: Media Server Management System

set -euo pipefail

# Configuration
COMPOSE_PATH="/docker/mediaserver"
LOG_FILE="./vpn-restart-handler.log"
VPN_CONTAINER="gluetun"
VPN_DEPENDENT_SERVICES=("sabnzbd" "deluge")

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check if container is healthy
is_container_healthy() {
    local container=$1
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    [[ "$health_status" == "healthy" ]]
}

# Function to wait for container to be healthy
wait_for_healthy() {
    local container=$1
    local timeout=${2:-120}  # Default 2 minutes
    local elapsed=0

    log "Waiting for $container to become healthy..."

    while ! is_container_healthy "$container"; do
        if [[ $elapsed -ge $timeout ]]; then
            log "ERROR: $container failed to become healthy within ${timeout}s"
            return 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        log "  ... waiting (${elapsed}s/${timeout}s)"
    done

    log "$container is healthy"
    return 0
}

# Function to restart VPN-dependent services
restart_vpn_dependent_services() {
    log "Restarting VPN-dependent services..."

    cd "$COMPOSE_PATH"

    # Stop dependent services first
    for service in "${VPN_DEPENDENT_SERVICES[@]}"; do
        log "Stopping $service..."
        docker compose stop "$service" || log "WARNING: Failed to stop $service"
    done

    # Wait a moment for clean shutdown
    sleep 5

    # Start dependent services
    for service in "${VPN_DEPENDENT_SERVICES[@]}"; do
        log "Starting $service..."
        docker compose up -d "$service" || log "ERROR: Failed to start $service"
    done

    log "VPN-dependent services restart completed"
}

# Function to perform full VPN restart sequence
restart_vpn_sequence() {
    log "Starting VPN restart sequence..."

    cd "$COMPOSE_PATH"

    # Stop dependent services first
    log "Stopping VPN-dependent services..."
    for service in "${VPN_DEPENDENT_SERVICES[@]}"; do
        docker compose stop "$service" || log "WARNING: Failed to stop $service"
    done

    # Restart VPN
    log "Restarting VPN container..."
    docker compose restart "$VPN_CONTAINER"

    # Wait for VPN to be healthy
    if wait_for_healthy "$VPN_CONTAINER" 180; then
        log "VPN is healthy, restarting dependent services..."
        restart_vpn_dependent_services
        log "VPN restart sequence completed successfully"
        return 0
    else
        log "ERROR: VPN restart sequence failed - VPN not healthy"
        return 1
    fi
}

# Function to handle orphaned network namespaces
fix_orphaned_namespaces() {
    log "Checking for orphaned network namespaces..."

    # Check if dependent services can reach external network
    local connection_test_failed=false

    for service in "${VPN_DEPENDENT_SERVICES[@]}"; do
        if ! docker exec "$service" ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
            log "WARNING: $service cannot reach external network"
            connection_test_failed=true
        fi
    done

    if $connection_test_failed; then
        log "Network connectivity issues detected, restarting dependent services..."
        restart_vpn_dependent_services
    else
        log "Network connectivity is normal"
    fi
}

# Main function
main() {
    case "${1:-}" in
        "restart-vpn")
            restart_vpn_sequence
            ;;
        "restart-dependent")
            restart_vpn_dependent_services
            ;;
        "fix-namespaces")
            fix_orphaned_namespaces
            ;;
        "check-health")
            log "Checking service health..."
            for service in "$VPN_CONTAINER" "${VPN_DEPENDENT_SERVICES[@]}"; do
                if docker ps --filter "name=$service" --filter "status=running" --quiet | grep -q .; then
                    if is_container_healthy "$service"; then
                        log "$service: HEALTHY"
                    else
                        log "$service: RUNNING (no health check or unhealthy)"
                    fi
                else
                    log "$service: NOT RUNNING"
                fi
            done
            ;;
        *)
            echo "Usage: $0 {restart-vpn|restart-dependent|fix-namespaces|check-health}"
            echo ""
            echo "Commands:"
            echo "  restart-vpn      - Full VPN restart sequence (stops dependents, restarts VPN, starts dependents)"
            echo "  restart-dependent - Restart only VPN-dependent services"
            echo "  fix-namespaces   - Check and fix orphaned network namespaces"
            echo "  check-health     - Check health status of all VPN-related services"
            exit 1
            ;;
    esac
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Run main function
main "$@"