# Execute Device Commands and Messages
# Polls Supabase for pending commands and executes them
# Also checks for broadcast messages and displays them

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY,
    [string]$DeviceHostname = $env:COMPUTERNAME
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Error "Supabase URL and Key must be provided"
    exit 1
}

# Normalize hostname: trim whitespace and convert to uppercase for consistent matching
$DeviceHostname = $DeviceHostname.Trim().ToUpper()
Write-Host "Normalized device hostname: '$DeviceHostname'" -ForegroundColor Cyan
Write-Host "Original COMPUTERNAME: '$env:COMPUTERNAME'" -ForegroundColor Gray

# Function to execute lock command
function Lock-Device {
    Write-Host "Locking device..." -ForegroundColor Yellow
    try {
        rundll32.exe user32.dll,LockWorkStation
        return $true
    } catch {
        Write-Error "Failed to lock device: $_"
        return $false
    }
}

# Function to execute clear cache command
function Clear-DeviceCache {
    Write-Host "Clearing device cache..." -ForegroundColor Yellow
    try {
        # Clear temp files
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Clear browser caches
        $chromeCache = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        $edgeCache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        
        if (Test-Path $chromeCache) {
            Remove-Item "$chromeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $edgeCache) {
            Remove-Item "$edgeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Clear Windows temp
        Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "Cache cleared successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Failed to clear cache: $_"
        return $false
    }
}

# Function to execute buzz command - runs in user session
function Buzz-Device {
    param([int]$Duration = 5)
    
    Write-Host "Buzzing device for $Duration seconds..." -ForegroundColor Yellow
    try {
        # Get logged-in user
        $loggedInUser = (Get-WmiObject -Class Win32_ComputerSystem).Username
        if (-not $loggedInUser) {
            Write-Warning "No logged-in user found for buzz command"
            return $false
        }
        
        # Create temporary script to run in user session
        $tempScript = "$env:TEMP\buzz-$(Get-Random).ps1"
        $durationMs = $Duration * 1000
        @"
`$endTime = (Get-Date).AddMilliseconds($durationMs)
while ((Get-Date) -lt `$endTime) {
    [console]::beep(800, 500)
    Start-Sleep -Milliseconds 500
}
"@ | Out-File $tempScript -Encoding UTF8
        
        # Create one-time scheduled task to run as logged-in user
        $taskName = "VigyanShaala-Buzz-$(Get-Random)"
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempScript`""
        $principal = New-ScheduledTaskPrincipal -UserId $loggedInUser `
            -LogonType Interactive -RunLevel Limited
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(1)
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 30) `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
        
        Register-ScheduledTask -TaskName $taskName -Action $action `
            -Principal $principal -Trigger $trigger -Settings $settings -Force | Out-Null
        
        # Wait for task to complete
        Start-Sleep -Seconds ($Duration + 3)
        
        # Cleanup
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        
        Write-Host "Buzz command executed in user session" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Failed to buzz device: $_"
        return $false
    }
}

# Function to show Windows Toast notification - runs in user session
function Show-ToastNotification {
    param([string]$Title, [string]$Message)
    
    try {
        # Get logged-in user
        $loggedInUser = (Get-WmiObject -Class Win32_ComputerSystem).Username
        if (-not $loggedInUser) {
            Write-Warning "No logged-in user found, using msg.exe fallback"
            msg.exe * "$Title - $Message" 2>$null
            return $true
        }
        
        # Create temporary script to show toast in user session
        $tempScript = "$env:TEMP\toast-$(Get-Random).ps1"
        $escapedTitle = $Title -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
        $escapedMessage = $Message -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
        
        @"
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

`$template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$escapedTitle</text>
            <text>$escapedMessage</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default" />
</toast>
"@

`$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
`$xml.LoadXml(`$template)
`$toast = [Windows.UI.Notifications.ToastNotification]::new(`$xml)
`$toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(5)
`$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("VigyanShaala MDM")
`$notifier.Show(`$toast)
"@ | Out-File $tempScript -Encoding UTF8
        
        # Create one-time scheduled task to run as logged-in user
        $taskName = "VigyanShaala-Toast-$(Get-Random)"
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempScript`""
        $principal = New-ScheduledTaskPrincipal -UserId $loggedInUser `
            -LogonType Interactive -RunLevel Limited
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(1)
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 30) `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
        
        Register-ScheduledTask -TaskName $taskName -Action $action `
            -Principal $principal -Trigger $trigger -Settings $settings -Force | Out-Null
        
        # Wait a bit then cleanup
        Start-Sleep -Seconds 3
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        
        Write-Host "Toast notification sent to user session" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Toast notification failed: $_"
        # Fallback to msg.exe (works from SYSTEM)
        try {
            msg.exe * "$Title - $Message" 2>$null
        } catch {}
        return $false
    }
}

# Function to display broadcast message (Toast + Chat Interface)
function Show-BroadcastMessage {
    param([string]$Message, [string]$MessageId)
    
    Write-Host "Broadcast Message: $Message" -ForegroundColor Cyan
    
    # Show toast notification
    Show-ToastNotification -Title "VigyanShaala MDM Broadcast" -Message $Message
    
    # Also add to chat_messages table so it appears in chat interface
    try {
        $headers = @{
            "apikey" = $SupabaseKey
            "Authorization" = "Bearer $SupabaseKey"
            "Content-Type" = "application/json"
        }
        
        # Use normalized hostname for consistency
        $normalizedHostname = $DeviceHostname.Trim().ToUpper()
        $body = @{
            device_hostname = $normalizedHostname
            sender = "center"
            message = "[BROADCAST] $Message"
        } | ConvertTo-Json
        
        $url = "$SupabaseUrl/rest/v1/chat_messages"
        Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body | Out-Null
        Write-Host "Broadcast message added to chat interface" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to add broadcast to chat: $_"
    }
}

# Function to check and execute commands
function Process-Commands {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
        "Content-Type" = "application/json"
    }
    
    # Get all pending commands for this device (process all, not just one)
    # Use case-insensitive matching by querying with ilike (PostgreSQL case-insensitive like)
    # Note: PostgREST doesn't support ilike directly, so we'll try exact match first, then try uppercase
    $commandUrl = "$SupabaseUrl/rest/v1/device_commands?device_hostname=eq.$DeviceHostname&command_type=in.(lock,unlock,clear_cache,buzz)&status=eq.pending&order=created_at.asc"
    
    Write-Host "Querying commands with hostname: '$DeviceHostname'" -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $commandUrl -Method GET -Headers $headers
        
        # If no results with exact match, try case-insensitive by querying all pending and filtering
        if (-not $response -or $response.Count -eq 0) {
            Write-Host "No commands found with exact hostname match, trying case-insensitive search..." -ForegroundColor Yellow
            # Get all pending commands and filter by case-insensitive hostname match
            $allCommandsUrl = "$SupabaseUrl/rest/v1/device_commands?command_type=in.(lock,unlock,clear_cache,buzz)&status=eq.pending&order=created_at.asc&select=*"
            $allCommands = Invoke-RestMethod -Uri $allCommandsUrl -Method GET -Headers $headers
            if ($allCommands) {
                $response = $allCommands | Where-Object { $_.device_hostname -and $_.device_hostname.Trim().ToUpper() -eq $DeviceHostname }
                if ($response) {
                    $response = @($response)  # Ensure it's an array
                    Write-Host "Found $($response.Count) command(s) with case-insensitive match" -ForegroundColor Green
                }
            }
        }
        
        if ($response -and $response.Count -gt 0) {
            Write-Host "Found $($response.Count) pending command(s) for device: $DeviceHostname" -ForegroundColor Cyan
            
            foreach ($command in $response) {
                Write-Host "Processing command: $($command.command_type) (ID: $($command.id))" -ForegroundColor Green
                
                $success = $false
                $errorMsg = $null
                
                switch ($command.command_type) {
                    "lock" {
                        $success = Lock-Device
                    }
                    "unlock" {
                        Write-Host "Unlock requires user interaction" -ForegroundColor Yellow
                        $errorMsg = "Unlock requires user password/pin"
                    }
                    "clear_cache" {
                        $success = Clear-DeviceCache
                    }
                    "buzz" {
                        $duration = if ($command.duration) { $command.duration } else { 5 }
                        $success = Buzz-Device -Duration $duration
                    }
                }
                
                # Update command status
                $updateUrl = "$SupabaseUrl/rest/v1/device_commands?id=eq.$($command.id)"
                $updateBody = @{
                    status = if ($success) { "completed" } else { "failed" }
                    executed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    error_message = $errorMsg
                } | ConvertTo-Json
                
                try {
                    Invoke-RestMethod -Uri $updateUrl -Method PATCH -Headers $headers -Body $updateBody | Out-Null
                    Write-Host "Command $($command.id) marked as $(if ($success) { 'completed' } else { 'failed' })" -ForegroundColor $(if ($success) { 'Green' } else { 'Red' })
                } catch {
                    Write-Error "Failed to update command status: $_"
                }
            }
        }
    } catch {
        Write-Error "Error processing commands: $_"
        Write-Host "Device hostname being used: $DeviceHostname" -ForegroundColor Yellow
    }
}

# Function to check and display broadcast messages
function Process-BroadcastMessages {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
        "Content-Type" = "application/json"
    }
    
    # Get pending broadcast messages
    $messageUrl = "$SupabaseUrl/rest/v1/device_commands?device_hostname=eq.$DeviceHostname&command_type=eq.broadcast_message&status=eq.pending&order=created_at.asc"
    
    try {
        $response = Invoke-RestMethod -Uri $messageUrl -Method GET -Headers $headers
        
        if ($response -and $response.Count -gt 0) {
            Write-Host "Found $($response.Count) pending broadcast message(s) for device: $DeviceHostname" -ForegroundColor Cyan
            
            foreach ($msg in $response) {
                if ($msg.message) {
                    Write-Host "Displaying broadcast message (ID: $($msg.id))" -ForegroundColor Green
                    Show-BroadcastMessage -Message $msg.message -MessageId $msg.id
                    
                    # Mark as dismissed
                    $updateUrl = "$SupabaseUrl/rest/v1/device_commands?id=eq.$($msg.id)"
                    $updateBody = @{
                        status = "dismissed"
                        executed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    } | ConvertTo-Json
                    
                    try {
                        Invoke-RestMethod -Uri $updateUrl -Method PATCH -Headers $headers -Body $updateBody | Out-Null
                        Write-Host "Broadcast message $($msg.id) marked as dismissed" -ForegroundColor Green
                    } catch {
                        Write-Error "Failed to update broadcast message status: $_"
                    }
                }
            }
        }
    } catch {
        Write-Error "Error processing broadcast messages: $_"
        Write-Host "Device hostname being used: $DeviceHostname" -ForegroundColor Yellow
    }
}

# Main execution - run once (scheduled task will call this repeatedly)
Write-Host "Processing commands/messages for device: $DeviceHostname" -ForegroundColor Green
Write-Host "Current time: $(Get-Date)" -ForegroundColor Gray

try {
    Process-Commands
    Process-BroadcastMessages
    Write-Host "Command/message processing completed" -ForegroundColor Green
} catch {
    Write-Error "Error in main execution: $_"
    exit 1
}
