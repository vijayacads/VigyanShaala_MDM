# Device Reinstallation Guide

## Overview

This guide walks you through uninstalling existing MDM installations and reinstalling with the new enhanced package that includes:
- Device health tracking
- Remote device control (lock, unlock, clear cache, buzz)
- Broadcast messaging
- Live chat support
- Updated device parameters

---

## Step 1: Uninstall Existing Installation

### Option A: Use the Uninstall Script (Recommended)

1. **Download the uninstall script** from the dashboard or use the one in the installer package:
   - `osquery-agent/uninstall-osquery.ps1`

2. **Run as Administrator**:
   ```powershell
   # Right-click PowerShell and select "Run as Administrator"
   cd C:\path\to\uninstall-script
   .\uninstall-osquery.ps1
   ```

3. **Confirm uninstallation** when prompted

4. **Verify removal**:
   - Check that osquery service is removed
   - Check that scheduled tasks are removed
   - Check that installation directory is removed

### Option B: Manual Uninstallation

1. **Stop and remove osquery service**:
   ```powershell
   Stop-Service osqueryd
   & "C:\Program Files\osquery\osqueryd.exe" --uninstall
   ```

2. **Uninstall via Windows Programs**:
   - Go to Settings → Apps → Apps & features
   - Find "osquery" and uninstall

3. **Remove scheduled tasks**:
   ```powershell
   Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-SyncWebsiteBlocklist" -Confirm:$false
   Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-SyncSoftwareBlocklist" -Confirm:$false
   Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-SendOsqueryData" -Confirm:$false
   Unregister-ScheduledTask -TaskName "VigyanShaala-MDM-CommandProcessor" -Confirm:$false
   ```

4. **Remove installation directory**:
   ```powershell
   Remove-Item "C:\Program Files\osquery" -Recurse -Force
   Remove-Item "C:\ProgramData\osquery" -Recurse -Force -ErrorAction SilentlyContinue
   ```

5. **Remove environment variables** (optional):
   ```powershell
   [System.Environment]::SetEnvironmentVariable("SUPABASE_URL", $null, "Machine")
   [System.Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", $null, "Machine")
   ```

---

## Step 2: Download New Installer Package

1. **Go to Dashboard**:
   - Navigate to: **Device Software Downloads** tab
   - Or go to: `dashboard/public/downloads/`

2. **Download the installer**:
   - Click "Download Windows Installer"
   - Save `VigyanShaala-MDM-Installer.zip` to the device

3. **Extract the ZIP file**:
   - Right-click → Extract All
   - Extract to a folder (e.g., `C:\MDM-Installer`)

---

## Step 3: Install New Package

### Method 1: Using RUN-AS-ADMIN.bat (Easiest)

1. **Navigate to extracted folder**

2. **Right-click `RUN-AS-ADMIN.bat`** → **Run as Administrator**

3. **Follow the prompts**:
   - The installer will automatically:
     - Install osquery
     - Copy configuration files
     - Set up environment variables
     - Create scheduled tasks
     - Launch enrollment wizard

4. **Complete enrollment**:
   - Select your location from the dropdown
   - Fill in device details (or use auto-fill)
   - Click "Enroll"

### Method 2: Manual Installation

1. **Open PowerShell as Administrator**

2. **Navigate to extracted folder**:
   ```powershell
   cd C:\path\to\extracted\folder
   ```

3. **Run the installer**:
   ```powershell
   .\INSTALL.ps1 -SupabaseUrl "YOUR_SUPABASE_URL" -SupabaseKey "YOUR_SUPABASE_KEY"
   ```

   Replace:
   - `YOUR_SUPABASE_URL`: Your Supabase project URL
   - `YOUR_SUPABASE_KEY`: Your Supabase anon key

4. **Wait for installation to complete**

5. **Run enrollment**:
   ```powershell
   cd osquery-agent
   .\enroll-device.ps1 -SupabaseUrl "YOUR_SUPABASE_URL" -SupabaseAnonKey "YOUR_SUPABASE_KEY"
   ```

---

## Step 4: Verify Installation

### Check Services

```powershell
Get-Service osqueryd
```

Should show: **Running**

### Check Scheduled Tasks

```powershell
Get-ScheduledTask | Where-Object {$_.TaskName -like "*VigyanShaala*"}
```

Should show 4 tasks:
- `VigyanShaala-MDM-SyncWebsiteBlocklist` (every 30 minutes)
- `VigyanShaala-MDM-SyncSoftwareBlocklist` (every hour)
- `VigyanShaala-MDM-SendOsqueryData` (every 5 minutes)
- `VigyanShaala-MDM-CommandProcessor` (every 30 seconds) ← **NEW**

### Check Files

Verify these files exist:
- `C:\Program Files\osquery\osquery.conf` (updated with health queries)
- `C:\Program Files\osquery\execute-commands.ps1` ← **NEW**
- `C:\Program Files\osquery\chat-interface.ps1` ← **NEW**

### Check Environment Variables

```powershell
[System.Environment]::GetEnvironmentVariable("SUPABASE_URL", "Machine")
[System.Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "Machine")
```

Should show your Supabase credentials.

---

## Step 5: Test New Features

### Test Device Health Tracking

1. **Wait 10-15 minutes** after installation
2. **Check dashboard** → Device Inventory
3. **Look for health status column** (Good/Warning/Critical)
4. **Check Supabase** → `device_health` table should have data

### Test Device Control

1. **Go to Dashboard** → Device Control tab
2. **Select your device**
3. **Click "Clear Cache"** (safest test)
4. **Wait 30-60 seconds**
5. **Check command history** - should show "completed"

### Test Broadcast Messages

1. **Go to Device Control tab**
2. **Select "All Devices"** or your location
3. **Enter test message**: "Testing broadcast - please acknowledge"
4. **Send message**
5. **Check device** - should show notification within 30 seconds

### Test Chat Support

1. **Go to Dashboard** → Live Chat tab
2. **Select your device**
3. **Send a test message**
4. **On device, run**:
   ```powershell
   cd "C:\Program Files\osquery"
   .\chat-interface.ps1
   ```
5. **Verify messages appear in real-time**

---

## Troubleshooting

### Installation Fails

**Problem**: Installer fails with errors

**Solutions**:
- Ensure running as Administrator
- Check Windows Defender isn't blocking PowerShell scripts
- Verify Supabase URL and key are correct
- Check internet connection

### Device Not Appearing in Dashboard

**Problem**: Device enrolled but not showing in dashboard

**Solutions**:
- Wait 5-10 minutes for first data sync
- Check osquery service is running
- Verify device hostname matches enrollment
- Check Supabase `devices` table directly

### Health Data Not Appearing

**Problem**: No health metrics after 15+ minutes

**Solutions**:
- Verify `osquery.conf` has health queries (check file)
- Restart osquery service: `Restart-Service osqueryd`
- Check edge function logs in Supabase
- Verify device is enrolled correctly

### Commands Not Executing

**Problem**: Commands stay in "pending" status

**Solutions**:
- Check `VigyanShaala-MDM-CommandProcessor` task is running
- Verify environment variables are set
- Check `execute-commands.ps1` exists in install directory
- Review task scheduler for errors

### Chat Not Working

**Problem**: Messages not appearing in real-time

**Solutions**:
- Verify Realtime is enabled for `chat_messages` table
- Check RLS policies allow access
- Verify Supabase credentials in environment variables
- Check network connectivity

---

## What's New in This Version

### New Features:
1. ✅ **Device Health Tracking** - Battery, storage, boot time, crashes
2. ✅ **Performance Status** - Auto-calculated (Good/Warning/Critical)
3. ✅ **Remote Device Control** - Lock, unlock, clear cache, buzz
4. ✅ **Broadcast Messaging** - Send messages to one or all devices
5. ✅ **Live Chat Support** - Real-time chat with devices
6. ✅ **Updated Parameters** - IMEI number, device make, role, issue date

### New Files:
- `execute-commands.ps1` - Processes commands and messages
- `chat-interface.ps1` - Chat UI for devices
- Updated `osquery.conf` - Health tracking queries

### New Scheduled Tasks:
- `VigyanShaala-MDM-CommandProcessor` - Runs every 30 seconds

---

## Quick Reference

### Installation Directory
```
C:\Program Files\osquery\
```

### Configuration File
```
C:\Program Files\osquery\osquery.conf
```

### Logs Location
```
C:\ProgramData\osquery\logs\
```

### Service Name
```
osqueryd
```

### Scheduled Tasks
- Website Blocklist Sync: Every 30 minutes
- Software Blocklist Sync: Every hour
- Data Sending: Every 5 minutes
- Command Processor: Every 30 seconds ← **NEW**

---

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Supabase edge function logs
3. Check Windows Event Viewer for errors
4. Verify all scheduled tasks are running
5. Contact administrator with error details

---

**Installation complete! Your device is now running the enhanced MDM agent.** 🎉

