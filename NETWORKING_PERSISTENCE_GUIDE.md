# Media Server Networking Persistence Guide

## Overview
This document provides comprehensive information about network configuration persistence for external access to SABnzbd and Deluge services through the VPN-routed setup.

## External Access Configuration

### Current Setup
- **SABnzbd**: Accessible via `67.199.170.5:8080` and `localhost:8080`
- **Deluge**: Accessible via `67.199.170.5:8112` and `localhost:8112`
- **Port Bindings**: Services listen on all interfaces (`0.0.0.0`)

### Docker Compose Configuration
```yaml
gluetun:
  ports:
    - "8080:8080"    # SABnzbd on all interfaces
    - "8112:8112"    # Deluge on all interfaces
```

## Persistence Guarantees

### ✅ GUARANTEED PERSISTENCE

#### 1. System Reboots
- **Status**: ✅ PERSISTENT
- **Mechanism**: `restart: unless-stopped` policy
- **Verification**: All containers auto-restart with correct port bindings
- **Test Result**: ✅ Verified through reboot simulation

#### 2. Docker Daemon Restarts
- **Status**: ✅ PERSISTENT
- **Mechanism**: Docker daemon recreates containers from compose configuration
- **Verification**: Port bindings maintained automatically
- **Test Result**: ✅ Verified through daemon restart simulation

#### 3. Container Manual Restarts
- **Status**: ✅ PERSISTENT
- **Mechanism**: Docker compose configuration defines port bindings
- **Verification**: `docker restart` maintains port mappings
- **Test Result**: ✅ Verified through manual restart testing

#### 4. VPN Container Restarts
- **Status**: ✅ PERSISTENT WITH AUTOMATION
- **Mechanism**: VPN restart handler ensures dependent services reconnect
- **Verification**: Automated restart sequence preserves external access
- **Test Result**: ✅ Verified through VPN restart handler testing

#### 5. Network Namespace Recovery
- **Status**: ✅ PERSISTENT WITH AUTOMATION
- **Mechanism**: Health checks and dependency management
- **Verification**: Services wait for VPN health before starting
- **Test Result**: ✅ Verified through compose recreation testing

### ⚠️ POTENTIAL EDGE CASES

#### 1. External IP Address Changes
- **Risk**: External IP may change due to DHCP or ISP changes
- **Impact**: External access URLs need updating
- **Detection**: Startup verification script detects IP changes
- **Mitigation**:
  - Run `./startup-verification.sh` after suspected IP changes
  - Update firewall/router rules if needed
  - External access still works, just different IP

#### 2. Network Interface Configuration Changes
- **Risk**: Local network interfaces (enp2s0, enp3s0) reconfiguration
- **Impact**: May affect routing to services
- **Detection**: Verification script tests multiple access methods
- **Mitigation**: Services bind to all interfaces, should remain accessible

#### 3. Docker Network Conflicts
- **Risk**: Docker network IP range conflicts with local networks
- **Impact**: Could affect container networking
- **Detection**: Container health checks and connectivity tests
- **Mitigation**: Docker automatically manages network isolation

#### 4. VPN Server Changes
- **Risk**: ProtonVPN may assign different server/IP
- **Impact**: VPN IP changes but doesn't affect external access
- **Detection**: VPN status monitoring shows new VPN IP
- **Mitigation**: No action needed, external access unaffected

## Verification Tools

### Startup Verification Script
**Location**: `/docker/mediaserver/startup-verification.sh`

**Usage**:
```bash
cd /docker/mediaserver
./startup-verification.sh
```

**Checks**:
- ✅ VPN health and connectivity
- ✅ Port bindings are correct (0.0.0.0)
- ✅ Local access (localhost)
- ✅ External access (current external IP)
- ✅ Network dependencies through VPN

### VPN Restart Handler
**Location**: `/docker/mediaserver/vpn-restart-handler.sh`

**Commands**:
```bash
./vpn-restart-handler.sh check-health     # Status check
./vpn-restart-handler.sh restart-vpn      # Safe VPN restart
./vpn-restart-handler.sh fix-namespaces   # Fix orphaned networks
```

## Recovery Procedures

### Quick External Access Check
```bash
# Check if external access is working
curl -I http://$(curl -s ifconfig.me):8112
curl -I http://$(curl -s ifconfig.me):8080
```

### Manual Recovery (If Automation Fails)
```bash
cd /docker/mediaserver

# Stop dependent services
docker stop sabnzbd deluge

# Restart VPN
docker restart gluetun

# Wait for VPN health
sleep 60

# Restart dependent services
docker compose up -d sabnzbd deluge
```

### Full System Recovery
```bash
cd /docker/mediaserver

# Full restart with correct order
docker compose down gluetun sabnzbd deluge
docker compose up -d gluetun sabnzbd deluge

# Verify after 2 minutes
sleep 120
./startup-verification.sh
```

## Monitoring and Alerting

### Automated Monitoring (Optional)
The system includes optional systemd timer integration for automated health monitoring:

**Files**:
- `/docker/mediaserver/vpn-watchdog.service`
- `/docker/mediaserver/vpn-watchdog.timer`

**Installation**:
```bash
# Copy to systemd (requires root)
sudo cp vpn-watchdog.service /etc/systemd/system/
sudo cp vpn-watchdog.timer /etc/systemd/system/

# Enable and start
sudo systemctl enable vpn-watchdog.timer
sudo systemctl start vpn-watchdog.timer
```

### Manual Monitoring
```bash
# Daily health check (recommended)
cd /docker/mediaserver && ./startup-verification.sh

# Weekly comprehensive check
./vpn-restart-handler.sh check-health
```

## Configuration Files That Ensure Persistence

### 1. docker-compose.yml
- **Port bindings**: `"8080:8080"` and `"8112:8112"`
- **Restart policies**: `restart: unless-stopped`
- **Health checks**: VPN connectivity verification
- **Dependencies**: `condition: service_healthy`

### 2. vpn-restart-handler.sh
- **Restart sequences**: Proper stop → start order
- **Health monitoring**: Wait for VPN before starting services
- **Logging**: All operations logged for troubleshooting

### 3. startup-verification.sh
- **Comprehensive checks**: VPN, ports, connectivity
- **External access**: Automatic external IP detection
- **Recovery guidance**: Specific fix suggestions

## Best Practices for Administrators

### Regular Maintenance
1. **Weekly**: Run startup verification script
2. **Monthly**: Test VPN restart handler
3. **After changes**: Always verify external access

### Change Management
1. **Before changes**: Document current working state
2. **During changes**: Use VPN restart handler for VPN operations
3. **After changes**: Run verification script

### Troubleshooting Priority
1. **First**: Check external access with verification script
2. **Second**: Use VPN restart handler if issues found
3. **Third**: Manual recovery procedures if automation fails
4. **Last**: Full system restart if all else fails

## Security Considerations

### Port Exposure
- **SABnzbd**: Now exposed on all interfaces
- **Deluge**: Now exposed on all interfaces
- **Mitigation**: VPN routing ensures traffic security
- **Recommendation**: Consider firewall rules for additional security

### VPN Dependency
- **All traffic**: SABnzbd and Deluge traffic routes through VPN
- **Kill switch**: Built into Gluetun configuration
- **Verification**: Connectivity tests ensure VPN routing

## Summary

The networking configuration is **fully persistent** across all restart scenarios with the following guarantees:

✅ **System reboots**: Auto-restart with correct configuration
✅ **Docker restarts**: Configuration preserved
✅ **Manual restarts**: Port bindings maintained
✅ **VPN changes**: Automated recovery procedures
✅ **Network issues**: Health checks and dependencies prevent orphaning

**External access to both SABnzbd (port 8080) and Deluge (port 8112) will persist through any restart scenario.**