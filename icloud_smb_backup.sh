#!/bin/bash

# --- LOAD ENVIRONMENT VARIABLES ---
# Load configuration from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# --- CONFIGURATION ---
# IMPORTANT: Use quotes for paths with spaces. Do NOT use backslashes (\) inside quotes.
SOURCE="/Users/$(whoami)/Library/Mobile Documents/com~apple~CloudDocs/"

SMB_URL="smb://$SMB_HOST/$SMB_SHARE"
 # The folder inside your share

# --- AUTO-DETECTION ---
# Extracts the last part of the SMB URL (the share name)
SHARE_NAME=$(basename "$SMB_URL")
MOUNT_POINT="/Volumes/$SMB_SHARE"
DESTINATION="$MOUNT_POINT/$SUBFOLDER"

DELAY_MINUTES=5       # Long delay only after a fresh system boot
NETWORK_DELAY_SECONDS=20      # Short delay on EVERY run (to allow WiFi to reconnect after sleep)

LOCKFILE="/tmp/icloud_smb_backup.lock"
LOGFILE="/tmp/icloud_smb_backup.log"
STARTUP_SENTINEL="/tmp/icloud_smb_backup_startup_done"
APP_NAME="iCloud SMB Backup"

# --- LOCK MECHANISM ---
# Prevents multiple instances of the script from running simultaneously
if [ -e "$LOCKFILE" ]; then exit 0; fi
touch "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

# --- NETWORK STABILIZATION ---
# Give the WiFi a few seconds to re-establish a connection after waking the Mac
sleep $NETWORK_DELAY_SECONDS

# --- STARTUP DELAY (Only after fresh boot/login) ---
# Check if the sentinel file exists in /tmp (cleared on reboot)
if [ ! -f "$STARTUP_SENTINEL" ]; then
    touch "$STARTUP_SENTINEL"
    echo "Fresh boot detected. Waiting an additional $DELAY_MINUTES minutes..." >> "$LOGFILE"
    sleep $((DELAY_MINUTES * 60))
fi

# --- LOG MANAGEMENT (Limit to ~1MB) ---
# If log is larger than 1024 KB, it will be cleared with a timestamp
if [ -f "$LOGFILE" ] && [ $(du -k "$LOGFILE" | cut -f1) -gt 1024 ]; then
    echo "--- Log cleared due to size on $(date) ---" > "$LOGFILE"
fi

# --- MOUNT LOGIC ---
# Check if the share is already mounted; if not, mount via AppleScript
if ! mount | grep "on $MOUNT_POINT" > /dev/null; then
    # Uses native macOS mount system to leverage Keychain credentials
    osascript -e "mount volume \"$SMB_URL\"" > /dev/null 2>&1
    sleep 5
fi

# --- SYNC EXECUTION ---
# Only proceed if the mount was successful
if mount | grep "on $MOUNT_POINT" > /dev/null; then
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Check for placeholder files (files not downloaded from iCloud)
    # This looks for hidden files ending in .icloud
    OFFLINE_FILES=$(find "$SOURCE" -name ".*.icloud" -type f | wc -l | xargs)

    if [ "$OFFLINE_FILES" -gt 0 ]; then
        echo "WARNING: $OFFLINE_FILES files are cloud-only and won't be backed up!" >> "$LOGFILE"
        osascript -e "display notification \"⚠️ $OFFLINE_FILES files not downloaded. Backup incomplete!\" with title \"$APP_NAME\""
    fi
    
    # Run rsync with itemized changes (-i) and preserve timestamps/links
    # Note: --no-perms is used to avoid permission conflicts with SMB
    SYNC_OUTPUT=$(rsync -ai --delete --no-perms --exclude '.DS_Store' "$SOURCE" "$DESTINATION" 2>&1)
    RSYNC_EXIT_CODE=$?

    echo "--- Start: $TIMESTAMP ---" >> "$LOGFILE"
    echo "$SYNC_OUTPUT" >> "$LOGFILE"

    if [ $RSYNC_EXIT_CODE -eq 0 ]; then
        # Only show notification if files were actually transferred
        if [ -n "$SYNC_OUTPUT" ]; then
            osascript -e "display notification \"iCloud files synced successfully.\" with title \"$APP_NAME\""
        fi
    else
        # Log error details and notify user
        echo "Error details: $SYNC_OUTPUT" >> "$LOGFILE"
        osascript -e "display notification \"⚠️ Sync error! Check log for details.\" with title \"$APP_NAME\""
    fi
else
    # Quiet exit if NAS is not reachable (e.g., when you are away from home)
    echo "$(date): SMB share not reachable or mount failed." >> "$LOGFILE"
fi
