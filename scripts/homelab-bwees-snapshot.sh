#!/bin/bash

# This script creates a new ZFS snapshot and keeps only the 4 most recent snapshots.
# It is intended to be run as a cron job, every 12 hours.
# Install it with 
# - name: Transfer docker-compose files to host
#   copy:
#     src: '../../scripts/homelab-bwees-snapshot.sh'
#     dest: '/home/zfsrepl/zfs-snapshot.sh'
#     mode: '0755'
#     force: true

# - name: Create cron job for ZFS Auto-snapshot, run every 12 hours
#   cron:
#     name: 'ZFS Auto-snapshot'
#     minute: '0'
#     hour: '*/12'
#     job: '/home/zfsrepl/zfs-snapshot.sh'
#     user: 'zfsrepl'
#     state: present


# Define dataset
DATASET="storage"  # Change this to your ZFS dataset

# Snapshot name format
SNAPSHOT_NAME="${DATASET}@autosnap-$(date +'%Y-%m-%d_%H-%M')"

# Create a new snapshot
zfs snapshot "$SNAPSHOT_NAME"

# Keep only the 4 most recent snapshots
zfs list -t snapshot -o name -s creation | grep "^${DATASET}@" | head -n -4 | xargs -r zfs destroy
