#!/bin/bash

set -euo pipefail

ACTION="${1:-}"

backup_create() {
    echo "Creating backup of Immich data..."
    
    # Create backup structure
    mkdir -p /mnt/backup/data
    
    # Backup user data (photos, videos, etc.)
    if [ -d "/data/library" ]; then
        echo "Backing up media library..."
        tar -czf /mnt/backup/data/library.tar.gz -C /data library/
    fi
    
    # Backup configuration
    if [ -d "/data/config" ]; then
        echo "Backing up configuration..."
        cp -r /data/config /mnt/backup/data/
    fi
    
    # Backup database (if present)
    if [ -d "/data/postgres" ]; then
        echo "Backing up database..."
        tar -czf /mnt/backup/data/postgres.tar.gz -C /data postgres/
    fi
    
    # Create backup metadata
    cat > /mnt/backup/backup_info.json <<EOF
{
    "version": "$(cat /usr/src/app/package.json | jq -r .version)",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "type": "immich"
}
EOF
    
    echo "Backup completed successfully"
}

backup_restore() {
    echo "Restoring Immich data from backup..."
    
    # Verify backup exists
    if [ ! -f "/mnt/backup/backup_info.json" ]; then
        echo "Error: No valid backup found"
        exit 1
    fi
    
    # Restore media library
    if [ -f "/mnt/backup/data/library.tar.gz" ]; then
        echo "Restoring media library..."
        mkdir -p /data
        tar -xzf /mnt/backup/data/library.tar.gz -C /data
    fi
    
    # Restore configuration
    if [ -d "/mnt/backup/data/config" ]; then
        echo "Restoring configuration..."
        mkdir -p /data
        cp -r /mnt/backup/data/config /data/
    fi
    
    # Restore database
    if [ -f "/mnt/backup/data/postgres.tar.gz" ]; then
        echo "Restoring database..."
        mkdir -p /data
        tar -xzf /mnt/backup/data/postgres.tar.gz -C /data
    fi
    
    # Set proper permissions
    chown -R 1001:1001 /data
    
    echo "Restore completed successfully"
}

case "$ACTION" in
    "create")
        backup_create
        ;;
    "restore")
        backup_restore
        ;;
    *)
        echo "Usage: $0 {create|restore}"
        exit 1
        ;;
esac