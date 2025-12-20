# RealtimeListener Testing Guide

## Step 1: Install Updated Installer on Test Device

### Download Installer
1. Get the latest `VigyanShaala-MDM-Installer.zip` from your deployment
2. Extract the ZIP file on your test Windows device

### Run Installation
1. Right-click `INSTALL.ps1` in the extracted folder
2. Select "Run with PowerShell" (Run as Administrator)
3. Wait for installation to complete
4. Verify success messages appear

**Expected Output:**
- `[3/6] Creating scheduled task for realtime command listener (WebSocket)...`
- `Realtime listener task created and enabled (runs at startup, restarts on failure)`

---

## Step 2: Check if RealtimeListener Task is Running

### Quick Check
```powershell
Get-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"
```

**Expected:** Task exists and shows `State: Ready` or `State: Running`

### Detailed Status Check
```powershell
$task = Get-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"
$taskInfo = Get-ScheduledTaskInfo -TaskName "VigyanShaala-MDM-RealtimeListener"

Write-Host "Task State: $($task.State)" -ForegroundColor $(if ($task.State -eq "Ready" -or $task.State -eq "Running") { "Green" } else { "Red" })
Write-Host "Last Run: $($taskInfo.LastRunTime)"
Write-Host "Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Red" })
```

**Expected:**
- State: `Ready` or `Running`
- Last Result: `0` (success)
- Last Run: Recent timestamp (within last few minutes)

### Check if Process is Running
```powershell
Get-Process | Where-Object { 
    $_.CommandLine -like "*realtime-command-listener*" 
} | Select-Object ProcessName, Id, StartTime
```

**Alternative (check via Task Manager):**
- Open Task Manager (Ctrl+Shift+Esc)
- Go to "Details" tab
- Look for `powershell.exe` processes
- Check command line contains `realtime-command-listener.ps1`

### Manually Start Task (if not running)
```powershell
Start-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"
Start-Sleep -Seconds 3
Get-ScheduledTaskInfo -TaskName "VigyanShaala-MDM-RealtimeListener"
```

---

## Step 3: Check Logs

### View Log File
```powershell
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Tail 50
```

### Monitor Logs in Real-Time
```powershell
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Wait -Tail 20
```

### Check for Errors
```powershell
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" | Select-String -Pattern "ERROR"
```

### Expected Log Entries (when working correctly):
```
[2025-01-XX XX:XX:XX] [INFO] Realtime Command Listener starting
[2025-01-XX XX:XX:XX] [INFO] Device: YOUR-DEVICE-NAME
[2025-01-XX XX:XX:XX] [INFO] Realtime WebSocket URL: wss://xxx.supabase.co/realtime/v1/websocket
[2025-01-XX XX:XX:XX] [INFO] WebSocket connected successfully
[2025-01-XX XX:XX:XX] [INFO] Subscribed to device_commands channel
```

### If Log File Doesn't Exist
- Task may not have started yet
- Check task status (Step 2)
- Manually start the task
- Wait 10 seconds and check again

---

## Step 4: Send Test Command from Dashboard

### From Dashboard UI
1. Open your MDM dashboard
2. Navigate to **Device Control** section
3. Select your test device from the device list
4. Choose a test command:
   - **Lock Device** - Quick test (device should lock immediately)
   - **Clear Cache** - Safe test (clears temp files)
   - **Buzz Device** - Audio test (device should beep)

5. Click the command button
6. Wait 2-5 seconds

### Verify Instant Delivery

#### Check Logs (within 2-5 seconds)
```powershell
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" -Tail 20
```

**Expected log entries:**
```
[2025-01-XX XX:XX:XX] [INFO] Received command notification: lock (ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
[2025-01-XX XX:XX:XX] [INFO] Executing lock command
[2025-01-XX XX:XX:XX] [INFO] Command xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx marked as completed
```

#### Check Database (Supabase Dashboard)
```sql
SELECT 
    id,
    device_hostname,
    command_type,
    status,
    created_at,
    executed_at,
    TIMESTAMPDIFF('second', created_at, executed_at) as delivery_time_seconds
FROM device_commands
WHERE device_hostname = 'YOUR-DEVICE-NAME'
ORDER BY created_at DESC
LIMIT 5;
```

**Expected:**
- `status` = `'completed'` (within 2-5 seconds)
- `executed_at` is set (not null)
- `delivery_time_seconds` < 5 seconds (instant delivery)

#### Check Command History in Dashboard
- Refresh the Device Control page
- Check "Command History" section
- Latest command should show:
  - Status: **Completed** (green checkmark)
  - Executed At: Recent timestamp
  - Time difference: < 5 seconds from "Created At"

---

## Troubleshooting

### Task Not Running

**Check if task exists:**
```powershell
Get-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener" -ErrorAction SilentlyContinue
```

**If task doesn't exist:**
- Re-run installer: `.\INSTALL.ps1`
- Check installer logs for errors

**If task exists but not running:**
```powershell
# Enable task
Enable-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"

# Start task manually
Start-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"

# Check status after 5 seconds
Start-Sleep -Seconds 5
Get-ScheduledTaskInfo -TaskName "VigyanShaala-MDM-RealtimeListener"
```

### No Logs Appearing

**Check log file path:**
```powershell
Test-Path "$env:TEMP\VigyanShaala-RealtimeListener.log"
```

**Check environment variables:**
```powershell
$env:SUPABASE_URL
$env:SUPABASE_ANON_KEY
$env:COMPUTERNAME
```

**Manually test script:**
```powershell
cd "C:\Program Files\osquery"
.\realtime-command-listener.ps1 -SupabaseUrl "YOUR_URL" -SupabaseKey "YOUR_KEY"
```

### Commands Not Processing

**Check WebSocket connection in logs:**
```powershell
Get-Content "$env:TEMP\VigyanShaala-RealtimeListener.log" | Select-String -Pattern "connected|error|ERROR"
```

**Verify Supabase Realtime is enabled:**
- Go to Supabase Dashboard
- Database → Replication
- Ensure `device_commands` table has Realtime enabled

**Check device hostname matching:**
```powershell
$env:COMPUTERNAME
# Should match device_hostname in database (case-insensitive, normalized to uppercase)
```

**Verify command was inserted:**
```sql
SELECT * FROM device_commands 
WHERE device_hostname = 'YOUR-DEVICE-NAME' 
AND status = 'pending'
ORDER BY created_at DESC
LIMIT 1;
```

### Commands Processing Slowly (>5 seconds)

**Check fallback polling task:**
```powershell
Get-ScheduledTask -TaskName "VigyanShaala-MDM-CommandProcessor" | Get-ScheduledTaskInfo
```

- If RealtimeListener fails, fallback polling (every 5 minutes) will process commands
- Check RealtimeListener logs for connection errors
- Verify network connectivity to Supabase

---

## Success Criteria

✅ RealtimeListener task exists and is enabled  
✅ Task is running (State: Ready or Running)  
✅ Log file exists and shows connection messages  
✅ WebSocket connected successfully  
✅ Test command processed within 2-5 seconds  
✅ Command status updated to "completed" in database  
✅ Logs show command received and executed  

---

## Quick Verification Script

Run this PowerShell script to check everything at once:

```powershell
Write-Host "`n=== RealtimeListener Status Check ===" -ForegroundColor Cyan

# Check task
$task = Get-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener" -ErrorAction SilentlyContinue
if ($task) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName "VigyanShaala-MDM-RealtimeListener"
    Write-Host "Task Status: $($task.State)" -ForegroundColor $(if ($task.State -eq "Ready" -or $task.State -eq "Running") { "Green" } else { "Yellow" })
    Write-Host "Last Run: $($taskInfo.LastRunTime)"
    Write-Host "Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Red" })
} else {
    Write-Host "Task NOT FOUND" -ForegroundColor Red
}

# Check log file
$logFile = "$env:TEMP\VigyanShaala-RealtimeListener.log"
if (Test-Path $logFile) {
    Write-Host "`nLog File: EXISTS" -ForegroundColor Green
    Write-Host "Last 5 log entries:" -ForegroundColor Cyan
    Get-Content $logFile -Tail 5
} else {
    Write-Host "`nLog File: NOT FOUND" -ForegroundColor Red
}

# Check process
$process = Get-Process | Where-Object { $_.CommandLine -like "*realtime-command-listener*" } | Select-Object -First 1
if ($process) {
    Write-Host "`nProcess: RUNNING (PID: $($process.Id))" -ForegroundColor Green
} else {
    Write-Host "`nProcess: NOT RUNNING" -ForegroundColor Yellow
}

Write-Host "`n=== Check Complete ===" -ForegroundColor Cyan
```




