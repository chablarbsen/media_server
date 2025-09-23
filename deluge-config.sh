#!/bin/bash

# Deluge Configuration Script for Private Tracker Optimization
# This script ensures Deluge maintains proper configuration across restarts

DELUGE_CONFIG="/config/core.conf"
DELUGE_BACKUP="/config/core.conf.backup"

# Wait for Deluge to start
sleep 10

# Function to update Deluge config
update_deluge_config() {
    echo "Applying Deluge configuration for private trackers..."

    # Stop daemon to safely modify config
    docker exec deluge pkill -f deluged
    sleep 5

    # Apply configuration using sed (more reliable than JSON editing)
    docker exec deluge sed -i 's/"max_active_downloading": [0-9]*/"max_active_downloading": 8/' /config/core.conf
    docker exec deluge sed -i 's/"max_active_limit": [0-9]*/"max_active_limit": 15/' /config/core.conf
    docker exec deluge sed -i 's/"max_active_seeding": [0-9]*/"max_active_seeding": 10/' /config/core.conf
    docker exec deluge sed -i 's/"dht": true/"dht": false/' /config/core.conf
    docker exec deluge sed -i 's/"lsd": true/"lsd": false/' /config/core.conf
    docker exec deluge sed -i 's/"utpex": true/"utpex": false/' /config/core.conf
    docker exec deluge sed -i 's/"upnp": true/"upnp": false/' /config/core.conf
    docker exec deluge sed -i 's/"natpmp": true/"natpmp": false/' /config/core.conf
    docker exec deluge sed -i 's/"allow_remote": false/"allow_remote": true/' /config/core.conf
    docker exec deluge sed -i 's/"max_download_speed": -1.0/"max_download_speed": 25000.0/' /config/core.conf
    docker exec deluge sed -i 's/"max_upload_speed": -1.0/"max_upload_speed": 10000.0/' /config/core.conf
    docker exec deluge sed -i 's/"max_half_open_connections": [0-9]*/"max_half_open_connections": 150/' /config/core.conf
    docker exec deluge sed -i 's/"max_connections_global": [0-9]*/"max_connections_global": 300/' /config/core.conf
    docker exec deluge sed -i 's/"prioritize_first_last_pieces": false/"prioritize_first_last_pieces": true/' /config/core.conf

    # Set proper listen port
    docker exec deluge sed -i 's/"listen_ports": \[[^]]*\]/"listen_ports": [58946, 58946]/' /config/core.conf

    # Create backup of our optimized config
    docker exec deluge cp /config/core.conf /config/core.conf.optimized

    echo "Deluge configuration applied successfully"
}

# Apply configuration
update_deluge_config

echo "Deluge private tracker configuration completed"