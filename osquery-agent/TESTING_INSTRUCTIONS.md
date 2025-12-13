# Testing Instructions: User Session Agent

## Prerequisites

1. **Apply Database Migration**
   - Run `supabase/migrations/022_create_user_notifications.sql` in your Supabase database
   - Verify the `user_notifications` table was created

2. **Install/Update Agent**
   - Run the installer: `install-osquery.ps1`
   - This will install/update the user-session notification agent

## Step-by-Step Testing

### 1. Verify Installation

**Check if user notification task exists:**
```powershell
Get-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent"
```

**Check task status:**
```powershell
Get-ScheduledTaskInfo -TaskName "VigyanShaala-UserNotify-Agent"
```

**Expected:** Task should exist and be enabled

### 2. Verify User Agent is Running

**Check if agent process is running:**
```powershell
Get-Process | Where-Object { $_.CommandLine -like "*user-notify-agent*" }
```

**Or check logs:**
```powershell
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 20
```

**Expected:** Log should show "User notification agent started" and polling messages

### 3. Test Buzz Command

**From Dashboard:**
1. Go to Device Control
2. Select a device
3. Click "Buzz Device" button
4. Wait 5-10 seconds

**Expected:**
- Device should play beep sound for the specified duration
- Command history should show "completed" status

**Manual Test (if dashboard doesn't work):**
```powershell
# Check if notification was created in database
# Query Supabase: SELECT * FROM user_notifications WHERE type = 'buzzer' ORDER BY created_at DESC LIMIT 1;
```

**Check logs:**
```powershell
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 30
```

**Expected:** Log should show:
- "Found X pending notification(s)"
- "Processing notification..."
- "Buzzer played for X seconds"

### 4. Test Toast Notification

**From Dashboard:**
1. Go to Device Control
2. Select a device
3. Send a broadcast message
4. Wait 5-10 seconds

**Expected:**
- Windows toast notification should appear
- Message should also appear in chat interface

**Manual Test:**
```powershell
# Check if notification was created
# Query Supabase: SELECT * FROM user_notifications WHERE type = 'toast' ORDER BY created_at DESC LIMIT 1;
```

**Check logs:**
```powershell
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" -Tail 30
```

**Expected:** Log should show:
- "Found X pending notification(s)"
- "Processing notification..."
- "Toast notification shown: [title]"

### 5. Verify Database Updates

**Check notification status:**
```sql
SELECT 
    id,
    device_hostname,
    username,
    type,
    status,
    created_at,
    processed_at,
    error_message
FROM user_notifications
ORDER BY created_at DESC
LIMIT 10;
```

**Expected:**
- Notifications should have `status = 'completed'` after processing
- `processed_at` should be set
- No `error_message` for successful notifications

### 6. Test Error Handling

**Test with no user logged in:**
- Log out all users
- Send a buzz command from dashboard
- Check logs for appropriate error messages

**Test with wrong username:**
- Manually insert a notification with wrong username
- Verify it doesn't get processed
- Check logs

## Troubleshooting

### Agent Not Running

**Check task:**
```powershell
Get-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent" | Format-List *
```

**Manually start:**
```powershell
Start-ScheduledTask -TaskName "VigyanShaala-UserNotify-Agent"
```

**Check if task runs at logon:**
- Log out and log back in
- Check if agent starts automatically

### Notifications Not Processing

**Check username matching:**
```powershell
# On device, check what username format is used
$env:USERNAME
$env:USERDOMAIN
[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
```

**Check hostname matching:**
```powershell
$env:COMPUTERNAME
# Should match device_hostname in database (case-insensitive, normalized to uppercase)
```

**Check database connection:**
```powershell
# Verify environment variables are set
$env:SUPABASE_URL
$env:SUPABASE_ANON_KEY
```

**Check logs for errors:**
```powershell
Get-Content "$env:TEMP\VigyanShaala-UserNotify.log" | Select-String -Pattern "ERROR"
```

### Buzz Not Playing

**Test beep manually:**
```powershell
[console]::beep(800, 500)
```

**Check Windows Audio service:**
```powershell
Get-Service -Name "Audiosrv"
```

**Check if agent is running in correct session:**
```powershell
# Agent should be running as logged-in user, not SYSTEM
Get-Process | Where-Object { $_.CommandLine -like "*user-notify-agent*" } | Select-Object ProcessName, Id, UserName
```

### Toast Not Showing

**Check Windows notification settings:**
- Settings → System → Notifications
- Ensure "VigyanShaala MDM" notifications are enabled

**Test toast manually:**
```powershell
# Run as logged-in user
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Test</text>
            <text>This is a test notification</text>
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

✅ User notification task exists and is enabled  
✅ Agent starts automatically at user logon  
✅ Agent logs show polling activity  
✅ Buzz commands play sound on device  
✅ Toast notifications appear on device  
✅ Notifications are marked as "completed" in database  
✅ Logs show successful processing  

## Next Steps After Testing

If all tests pass:
- Deploy to production
- Monitor logs for first few days
- Collect user feedback

If tests fail:
- Check logs for specific error messages
- Verify database migration was applied
- Verify environment variables are set correctly
- Check username/hostname matching

