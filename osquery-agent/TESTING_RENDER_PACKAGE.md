# Testing Instructions: Render Package Download Scenario

## Overview

This guide is specifically for testing when you download the installer package from Render, which already has Supabase credentials pre-configured.

## Step 1: Apply Database Migration

**In Supabase Dashboard:**
1. Go to SQL Editor
2. Open file: `supabase/migrations/022_create_user_notifications.sql`
3. Copy the entire SQL content
4. Paste into SQL Editor
5. Click "Run" to execute
6. Verify: You should see "Success. No rows returned"

**Verify table was created:**
```sql
SELECT * FROM user_notifications LIMIT 1;
```

## Step 2: Download and Install Package from Render

**Download the installer package:**
1. Go to your Render dashboard
2. Navigate to the service that hosts the installer download
3. Download `VigyanShaala-MDM-Installer.zip` (or the latest installer package)
4. Extract the ZIP file on your test Windows device

**Install the agent:**
1. Right-click on `INSTALL.ps1` in the extracted folder
2. Select "Run with PowerShell" (or run as Administrator)
3. The installer will:
   - Install osquery
   - Copy all agent scripts (including `user-notify-agent.ps1`)
   - Create scheduled tasks (including `VigyanShaala-UserNotify-Agent`)
   - Set up environment variables with Supabase credentials from Render

**Note:** The package from Render already contains the Supabase URL and API key, so you don't need to provide them manually.

**Verify installation completed:**
- Check for success messages in the PowerShell window
- Look for: "User notification agent task created (runs at user logon)"

## Step 3: Verify User Agent is Running

**After installation, log out and log back in** (or restart the computer) to trigger the user-session agent.

**Check if user notification task exists:**
```powershell
Get-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent"
```

**Check task status:**
```powershell
Get-ScheduledTaskInfo -TaskName "VigyanShaala-UserNotify-Agent"
```

**Expected:** Task should exist, be enabled, and show "Ready" status

**Check if agent process is running:**
```powershell
Get-Process | Where-Object { $_.ProcessName -eq "powershell" } | Where-Object { 
    $_.CommandLine -like "*user-notify-agent*" 
}
```

**Check agent logs:**
```powershell
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 20
```

**Expected:** Log should show:
- "User notification agent started"
- "Device: [YOUR_DEVICE_NAME], User: [YOUR_USERNAME]"
- "Starting notification polling (interval: 5 seconds)"

**If agent is not running:**
```powershell
# Manually start the task
Start-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent"

# Wait a few seconds, then check logs again
Start-Sleep -Seconds 5
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 10
```

## Step 4: Test Buzz Command

**From Dashboard (hosted on Render):**
1. Open your MDM dashboard (hosted on Render)
2. Go to Device Control section
3. Select your test device from the multi-select device picker
4. Click "🔊 Buzz Device" button
5. Select duration (e.g., 5 seconds)
6. Confirm the action
7. Wait 5-10 seconds

**Expected:**
- Device should play beep sound for the specified duration
- Command history should show "completed" status within 10-15 seconds

**Verify in logs:**
```powershell
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 30
```

**Expected log entries:**
- "Found 1 pending notification(s)"
- "Processing notification [id] (type: buzzer)"
- "Buzzer played for X seconds (Y beeps)"
- "Notification [id] marked as completed"

**Verify in database (Supabase Dashboard):**
```sql
SELECT 
    id,
    device_hostname,
    username,
    type,
    status,
    payload,
    created_at,
    processed_at
FROM user_notifications
WHERE type = 'buzzer'
ORDER BY created_at DESC
LIMIT 5;
```

**Expected:**
- Latest notification should have `status = 'completed'`
- `processed_at` should be set (within last few minutes)
- `payload` should contain `{"duration": 5}` (or your selected duration)

## Step 5: Test Toast Notification

**From Dashboard:**
1. Go to Device Control section
2. Scroll to "📢 Broadcast Message"
3. Select your test device(s) from the device list
4. Type a test message (e.g., "Test notification from Render deployment")
5. Click "📤 Send Broadcast"
6. Wait 5-10 seconds

**Expected:**
- Windows toast notification should appear in bottom-right corner
- Toast should show: "VigyanShaala MDM Broadcast" as title
- Your message should appear in the toast body
- Message should also appear in the chat interface (if you open it)

**Verify in logs:**
```powershell
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 30
```

**Expected log entries:**
- "Found 1 pending notification(s)"
- "Processing notification [id] (type: toast)"
- "Toast notification shown: VigyanShaala MDM Broadcast"
- "Notification [id] marked as completed"

**Verify in database:**
```sql
SELECT 
    id,
    device_hostname,
    username,
    type,
    status,
    payload,
    created_at,
    processed_at
FROM user_notifications
WHERE type = 'toast'
ORDER BY created_at DESC
LIMIT 5;
```

**Expected:**
- Latest notification should have `status = 'completed'`
- `payload` should contain `{"title": "...", "message": "..."}`

## Step 6: Verify End-to-End Flow

**Complete test scenario:**
1. **Send command from dashboard** → Should appear in `device_commands` table
2. **SYSTEM agent processes command** → Writes to `user_notifications` table
3. **User agent picks up notification** → Processes within 5-10 seconds
4. **Notification executed** → Buzz plays or toast appears
5. **Status updated** → `user_notifications.status = 'completed'`

**Check all tables:**
```sql
-- Check device commands
SELECT id, device_hostname, command_type, status, created_at, executed_at
FROM device_commands
WHERE command_type IN ('buzz', 'broadcast_message')
ORDER BY created_at DESC
LIMIT 5;

-- Check user notifications
SELECT id, device_hostname, username, type, status, created_at, processed_at
FROM user_notifications
ORDER BY created_at DESC
LIMIT 5;
```

**Expected:**
- Commands should be marked as "completed" or "pending"
- User notifications should be marked as "completed"
- Timestamps should be recent (within last few minutes)

## Troubleshooting

### Agent Not Running After Installation

**Check if task was created:**
```powershell
Get-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent" | Format-List *
```

**Check environment variables:**
```powershell
$env:SUPABASE_URL
$env:SUPABASE_ANON_KEY
```

**If variables are not set, check system environment variables:**
```powershell
[System.Environment]::GetEnvironmentVariable("SUPABASE_URL", "Machine")
[System.Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY", "Machine")
```

**Manually start the agent:**
```powershell
# Navigate to installation directory
cd "C:\Program Files\osquery"

# Run agent manually (for testing)
.\user-notify-agent.ps1
```

### Notifications Not Processing

**Check username/hostname matching:**
```powershell
# Check what the agent sees
$env:COMPUTERNAME
$env:USERNAME
$env:USERDOMAIN

# Check logs for matching issues
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" | Select-String -Pattern "Device:|User:"
```

**Verify database connection:**
```powershell
# Test Supabase connection
$headers = @{
    "apikey" = $env:SUPABASE_ANON_KEY
    "Authorization" = "Bearer $env:SUPABASE_ANON_KEY"
}
Invoke-RestMethod -Uri "$env:SUPABASE_URL/rest/v1/user_notifications?limit=1" -Headers $headers
```

### Buzz/Toast Not Working

**Check if agent is running in correct session:**
```powershell
# Agent should be running as logged-in user, not SYSTEM
Get-Process | Where-Object { $_.CommandLine -like "*user-notify-agent*" } | 
    Select-Object ProcessName, Id, UserName
```

**Test beep manually:**
```powershell
[console]::beep(800, 500)
```

**Test toast manually:**
```powershell
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Test</text>
            <text>Manual test notification</text>
        </binding>
    </visual>
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("VigyanShaala MDM")
$notifier.Show($toast)
```

## Success Criteria

✅ Database migration applied successfully  
✅ Installer package downloaded and installed  
✅ User notification task exists and is enabled  
✅ Agent starts automatically at user logon  
✅ Agent logs show polling activity  
✅ Buzz commands play sound on device  
✅ Toast notifications appear on device  
✅ Notifications are marked as "completed" in database  
✅ Logs show successful processing  

## Next Steps

If all tests pass:
- Deploy to production devices
- Monitor logs for first few days
- Collect user feedback

If tests fail:
- Check logs for specific error messages
- Verify database migration was applied
- Verify environment variables are set correctly
- Check username/hostname matching

