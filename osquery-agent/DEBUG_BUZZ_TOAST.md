# Debugging Guide: Buzzer and Toast Notification Issues

## Current Status
- ✅ Broadcast messages appear in chat interface (working)
- ❌ Buzzer sound not playing on devices
- ❌ Toast notifications not appearing on devices

## Why Chat Works But Toast/Buzzer Don't

### Chat Messages (Working)
- Chat messages are inserted into `chat_messages` table in Supabase
- The chat interface (`chat-interface.ps1`) polls Supabase directly
- Runs in user's interactive session when user opens the chat app
- No special permissions needed - just database reads

### Toast Notifications & Buzzer (Not Working)
- These need to run in the user's interactive session
- Currently executed via scheduled tasks from `execute-commands.ps1`
- `execute-commands.ps1` runs as SYSTEM account (Session 0)
- SYSTEM account cannot access user's desktop/audio session

## Root Cause Analysis

### The Problem
1. **Scheduled Task Context**: `VigyanShaala-MDM-CommandProcessor` runs as SYSTEM
2. **Session Isolation**: SYSTEM runs in Session 0 (non-interactive)
3. **User Session**: Logged-in user runs in Session 1+ (interactive)
4. **API Limitations**: 
   - `[console]::beep()` requires interactive console session
   - Windows Toast API requires user session context
   - Audio APIs need access to user's audio device

### Current Implementation Attempt
The code tries to bridge this gap by:
1. Detecting logged-in user via `Get-WmiObject Win32_ComputerSystem`
2. Creating temporary scheduled tasks that run as the logged-in user
3. Executing buzz/toast in those user-context tasks

## Potential Issues & Debugging Steps

### Issue 1: User Detection Failing
**Check**: Is the logged-in user being detected correctly?

**Debug Steps**:
```powershell
# Run on device as SYSTEM (via scheduled task or manually)
$loggedInUser = (Get-WmiObject -Class Win32_ComputerSystem).Username
Write-Host "Detected user: $loggedInUser"

# Alternative method
$explorerProcess = Get-WmiObject Win32_Process | Where-Object { $_.Name -eq "explorer.exe" }
if ($explorerProcess) {
    $owner = $explorerProcess.GetOwner()
    Write-Host "Explorer owner: $($owner.User)"
}
```

**Expected**: Should show domain\username or .\username
**If empty/null**: User detection is failing

### Issue 2: Scheduled Task Not Running in User Context
**Check**: Are the temporary scheduled tasks being created and executed?

**Debug Steps**:
```powershell
# Check if tasks are being created
Get-ScheduledTask | Where-Object { $_.TaskName -like "VigyanShaala-*" } | Format-List

# Check task execution history
Get-WinEvent -LogName Microsoft-Windows-TaskScheduler/Operational | 
    Where-Object { $_.Message -like "*VigyanShaala*" } | 
    Select-Object -First 10 TimeCreated, Message

# Manually test creating a user-context task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"[console]::beep(800,500)`""
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(2)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Test-Buzz" -Action $action -Principal $principal -Trigger $trigger -Settings $settings
Start-ScheduledTask -TaskName "Test-Buzz"
Start-Sleep -Seconds 5
Unregister-ScheduledTask -TaskName "Test-Buzz" -Confirm:$false
```

**Expected**: Task should execute and beep should play
**If fails**: Task creation or execution permissions issue

### Issue 3: Toast Notification API Not Available
**Check**: Is the Windows Toast API accessible in the user context?

**Debug Steps**:
```powershell
# Test toast notification directly (run as logged-in user, not SYSTEM)
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Test Toast</text>
            <text>This is a test notification</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default" />
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("VigyanShaala MDM")
$notifier.Show($toast)
```

**Expected**: Toast notification should appear
**If fails**: Windows version compatibility or API access issue

### Issue 4: Audio Service Not Running
**Check**: Is Windows Audio service enabled and running?

**Debug Steps**:
```powershell
# Check audio service status
Get-Service -Name "Audiosrv" | Format-List

# Check if audio is available
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class AudioCheck {
    [DllImport("kernel32.dll")]
    public static extern bool Beep(int frequency, int duration);
}
"@
[AudioCheck]::Beep(800, 500)
```

**Expected**: Beep should play
**If fails**: Audio service disabled or hardware issue

### Issue 5: Task Execution Timing
**Check**: Are tasks executing too quickly or being cleaned up before execution?

**Debug Steps**:
```powershell
# Add logging to execute-commands.ps1
Write-Host "Creating task: $taskName" -ForegroundColor Cyan
Write-Host "Task will run at: $((Get-Date).AddSeconds(1))" -ForegroundColor Cyan
Write-Host "Waiting for task execution..." -ForegroundColor Yellow

# Check task status immediately after creation
Start-Sleep -Seconds 2
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "Task State: $($taskInfo.State)" -ForegroundColor Cyan
    Write-Host "Last Run: $($taskInfo.LastRunTime)" -ForegroundColor Cyan
    Write-Host "Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor Cyan
}
```

**Expected**: Task should show as "Running" or "Ready" and execute
**If fails**: Task scheduling or timing issue

### Issue 6: PowerShell Execution Policy
**Check**: Can PowerShell execute scripts in the user context?

**Debug Steps**:
```powershell
# Check execution policy for current user
Get-ExecutionPolicy -Scope CurrentUser

# Test script execution
$testScript = "$env:TEMP\test-execution.ps1"
"Write-Host 'Script executed successfully'" | Out-File $testScript
PowerShell.exe -ExecutionPolicy Bypass -File $testScript
Remove-Item $testScript
```

**Expected**: Script should execute without errors
**If fails**: Execution policy blocking script execution

## Recommended Debugging Approach

### Step 1: Add Comprehensive Logging
Add detailed logging to `execute-commands.ps1`:
- Log detected user
- Log task creation details
- Log task execution status
- Log any errors with full stack traces

### Step 2: Test Each Component Individually
1. **Test user detection** - Run detection code manually
2. **Test task creation** - Create a test task manually
3. **Test buzz directly** - Run beep command as logged-in user
4. **Test toast directly** - Run toast code as logged-in user
5. **Test scheduled execution** - Create and trigger a test task

### Step 3: Check Windows Event Logs
```powershell
# Check Task Scheduler logs
Get-WinEvent -LogName Microsoft-Windows-TaskScheduler/Operational -MaxEvents 50 | 
    Where-Object { $_.Message -like "*VigyanShaala*" -or $_.Message -like "*buzz*" -or $_.Message -like "*toast*" }

# Check Application logs for PowerShell errors
Get-WinEvent -LogName Application -MaxEvents 50 | 
    Where-Object { $_.ProviderName -eq "PowerShell" -or $_.Message -like "*VigyanShaala*" }
```

### Step 4: Verify Scheduled Task Configuration
Check the actual scheduled task settings:
```powershell
$task = Get-ScheduledTask -TaskName "VigyanShaala-MDM-CommandProcessor"
$task | Format-List
$task.Principal | Format-List
$task.Settings | Format-List
```

## Alternative Solutions to Consider

### Solution 1: Use Windows Service with Session Notification
- Create a Windows service that runs as SYSTEM
- Service detects user logon events
- Service creates user-context processes for UI/audio operations
- More complex but more reliable

### Solution 2: Use Task Scheduler User Tasks
- Create tasks that trigger on user logon
- Tasks run in user context automatically
- Poll for commands from user context
- Simpler but requires user to be logged in

### Solution 3: Use WMI Events
- Subscribe to user logon events
- Trigger command processing on logon
- Execute in user context via WMI
- More event-driven approach

### Solution 4: Use PowerShell Remoting
- Execute commands via PowerShell remoting to user session
- Requires WinRM configuration
- More secure but complex setup

## Immediate Action Items

1. **Add logging** to `execute-commands.ps1` to capture:
   - Detected username
   - Task creation success/failure
   - Task execution results
   - Any errors with full details

2. **Create test script** that can be run manually to verify:
   - User detection works
   - Task creation works
   - Buzz works when run as user
   - Toast works when run as user

3. **Check logs** on a test device:
   - Task Scheduler operational logs
   - Application event logs
   - PowerShell execution logs

4. **Verify** the temporary scripts are being created correctly:
   - Check `$env:TEMP` for `buzz-*.ps1` and `toast-*.ps1` files
   - Verify script content is correct
   - Check if scripts are being cleaned up too early

## Questions to Answer

1. **Is the logged-in user being detected?**
   - Check logs for detected username
   - Verify it matches actual logged-in user

2. **Are temporary scheduled tasks being created?**
   - Check Task Scheduler for VigyanShaala-* tasks
   - Verify task properties (user, trigger, action)

3. **Are tasks executing?**
   - Check Task Scheduler history
   - Check Windows event logs
   - Verify task completion status

4. **Do buzz/toast work when run directly as user?**
   - Test beep command manually
   - Test toast notification manually
   - Verify Windows Audio service is running

5. **Are there permission issues?**
   - Check if SYSTEM can create tasks for users
   - Verify user has permissions to run scheduled tasks
   - Check Group Policy restrictions

## Next Steps

Once we identify which component is failing, we can:
1. Fix the specific issue
2. Implement a more robust solution
3. Add better error handling and fallbacks
4. Document the working solution

