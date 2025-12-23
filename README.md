# iCloud Backup to SMB Share

## Prerequisites

### Grant Full Disk Access

This allows the script (running via the shell) to read your local files and write to external volumes.

1. Open **System Settings**
1. Navigate to **Privacy & Security** > **Full Disk Access**
1. Click the **+** (plus) button (you may need to authenticate)
1. Add the following two items:
   - **Terminal**: Found in `/Applications/Utilities/Terminal.app`
   - **bash**: This is a system binary. When the file picker opens, press `Cmd + Shift + G`, type `/bin/bash`, and hit Enter
1. Ensure the toggle switches for both **Terminal** and **bash** are turned **ON**

### Grant Access to Network Volumes

macOS may explicitly ask if "sh" or "bash" can access files on a network volume.

1. Go to **System Settings** > **Privacy & Security** > **Files and Folders**
1. Look for **bash** or **sh** in the list
1. Ensure that **Network Volumes** is enabled

### 3. Keychain Access (Authentication)

The script uses `osascript` to mount the SMB share. To ensure this happens without a manual password prompt:

1. Mount your SMB share manually once in Finder (`Cmd + K`)
1. Enter your credentials and check the box **"Remember this password in my keychain"**
1. The first time the script runs, macOS might ask: _"Terminal wants to access the 'login' keychain"_. Select **"Always Allow"**

## Set environment variables

Rename `.env.example` to `.env` and fill in the details

## Enable

Make the script files executable:

```bash
chmod +x icloud_smb_backup.sh
```

Set username in `launchd` configuration and copy it to the right place:

```bash
sed "s/{{USERNAME}}/$(whoami)/g" com.user.icloud_smb_backup.plist > ~/Library/LaunchAgents/com.user.icloud_smb_backup.plist
```

Activate the `launchd` config:

```bash
launchctl load ~/Library/LaunchAgents/com.user.icloud_smb_backup.plist
```

## Check

See if the job was loaded:

```bash
launchctl list | grep icloud_smb_backup
```

Check the logs:

```bash
tail -f /tmp/icloud_smb_backup.log
```

## Disable

Deactivate the `launchd` config:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.icloud_smb_backup.plist
```

Delete the `launchd` config:

```bash
rm ~/Library/LaunchAgents/com.user.icloud_smb_backup.plist
```
