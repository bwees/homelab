#!/bin/bash

# This script creates a new ZFS snapshot and keeps only the 4 most recent snapshots.
# It is intended to be run as a cron job, every 12 hours.
# Install it with `just zfs-autosnap <HOST>`.

# Define dataset
DATASET="storage"  # Change this to your ZFS dataset

# Snapshot name format
SNAPSHOT_NAME="${DATASET}@autosnap-$(date +'%Y-%m-%d_%H-%M')"

# Create a new snapshot
zfs snapshot "$SNAPSHOT_NAME"

# Keep only the 4 most recent snapshots
zfs list -t snapshot -o name -s creation | grep "^${DATASET}@" | head -n -4 | xargs -r zfs destroy
