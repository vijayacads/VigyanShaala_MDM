# User Session Notification Agent
# Runs in logged-in user's session to handle buzz and toast notifications
# Polls Supabase for pending notifications and executes them

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY,
    [string]$DeviceHostname = $env:COMPUTERNAME,
    [string]$PollInterval = 5,  # seconds
    [string]$LogFile = "C:\ProgramData\VigyanShaala-MDM\logs\VigyanShaala-UserNotify.log"
)

# Normalize hostname
$DeviceHostname = $DeviceHostname.Trim().ToUpper()

# Ensure log directory exists
$logDir = Split-Path -Parent $LogFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
# Use same format as execute-commands.ps1 (WMI) to match stored usernames
$FullUsername = (Get-WmiObject -Class Win32_ComputerSystem).Username
if (-not $FullUsername) {
    # Fallback to env vars if WMI fails
    $CurrentUsername = $env:USERNAME
    $CurrentDomain = $env:USERDOMAIN
    $FullUsername = if ($CurrentDomain -and $CurrentDomain -ne $env:COMPUTERNAME) {
        "$CurrentDomain\$CurrentUsername"
    } else {
        $CurrentUsername
    }
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    } catch {
        # If logging fails, continue silently
    }
    # Only write to console if running interactively (for debugging)
    if ([Environment]::UserInteractive) {
        Write-Host $logMessage
    }
}

Write-Log "User notification agent started" "INFO"
Write-Log "Device: $DeviceHostname, User: $FullUsername" "INFO"

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Log "Supabase URL or Key not provided. Exiting." "ERROR"
    exit 1
}

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

# Function to show Windows Toast notification
function Show-ToastNotification {
    param([string]$Title, [string]$Message)
    
    # Try modern toast API first
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        # Escape XML special characters
        $escapedTitle = $Title -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
        $escapedMessage = $Message -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'

        $template = @"
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

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        $toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(5)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("VigyanShaala MDM")
        $notifier.Show($toast)
        
        Write-Log "Toast notification shown via Windows.UI.Notifications: $Title" "INFO"
        return $true
    } catch {
        Write-Log "Windows.UI.Notifications failed, trying MessageBox fallback: $_" "WARN"
    }
    
    # Fallback to MessageBox (always works)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        Write-Log "Toast notification shown via MessageBox: $Title" "INFO"
        return $true
    } catch {
        Write-Log "Failed to show toast notification: $_" "ERROR"
        return $false
    }
}

# Function to play buzzer sound
function Play-Buzzer {
    param([int]$Duration = 5)
    
    try {
        $endTime = (Get-Date).AddSeconds($Duration)
        $beepCount = 0
        while ((Get-Date) -lt $endTime) {
            [console]::beep(800, 500)
            Start-Sleep -Milliseconds 500
            $beepCount++
        }
        Write-Log "Buzzer played for $Duration seconds ($beepCount beeps)" "INFO"
        return $true
    } catch {
        Write-Log "Failed to play buzzer: $_" "ERROR"
        return $false
    }
}

# Function to lock device (runs in user session)
function Lock-Device {
    Write-Log "Locking device..." "INFO"
    try {
        $process = Start-Process -FilePath "rundll32.exe" -ArgumentList "user32.dll,LockWorkStation" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Log "Device locked successfully" "INFO"
            return $true
        } else {
            Write-Log "Lock command exited with code: $($process.ExitCode)" "WARN"
            return $false
        }
    } catch {
        Write-Log "Failed to lock device: $_" "ERROR"
        return $false
    }
}

# Function to unlock device (runs in user session)
# Note: Unlock typically requires user password/pin, but we can attempt it
function Unlock-Device {
    Write-Log "Unlock command received - requires user interaction (password/pin)" "INFO"
    # Unlock requires user to enter password/pin manually
    # We mark it as completed since the command was received
    # The actual unlock happens when user enters credentials
    Write-Log "User must enter password/pin to unlock" "INFO"
    return $true
}

# Function to clear device cache (runs in user session)
function Clear-DeviceCache {
    Write-Log "Clearing device cache..." "INFO"
    $clearedCount = 0
    $errorCount = 0
    
    try {
        # Clear current user's temp files
        $userTemp = "$env:TEMP"
        if (Test-Path $userTemp) {
            try {
                Get-ChildItem -Path $userTemp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $clearedCount++
                Write-Log "Cleared user temp: $userTemp" "DEBUG"
            } catch {
                $errorCount++
                Write-Log "Could not clear user temp: $_" "WARN"
            }
        }
        
        # Clear Windows temp
        $winTemp = "C:\Windows\Temp"
        if (Test-Path $winTemp) {
            try {
                Get-ChildItem -Path $winTemp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $clearedCount++
                Write-Log "Cleared Windows temp: $winTemp" "DEBUG"
            } catch {
                $errorCount++
                Write-Log "Could not clear Windows temp: $_" "WARN"
            }
        }
        
        # Clear browser caches for current user
        $userProfile = $env:USERPROFILE
        if ($userProfile) {
            $chromeCache = "$userProfile\AppData\Local\Google\Chrome\User Data\Default\Cache"
            $edgeCache = "$userProfile\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
            
            if (Test-Path $chromeCache) {
                try {
                    Get-ChildItem -Path $chromeCache -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    $clearedCount++
                    Write-Log "Cleared Chrome cache: $chromeCache" "DEBUG"
                } catch {
                    $errorCount++
                    Write-Log "Could not clear Chrome cache: $_" "WARN"
                }
            }
            
            if (Test-Path $edgeCache) {
                try {
                    Get-ChildItem -Path $edgeCache -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    $clearedCount++
                    Write-Log "Cleared Edge cache: $edgeCache" "DEBUG"
                } catch {
                    $errorCount++
                    Write-Log "Could not clear Edge cache: $_" "WARN"
                }
            }
        }
        
        if ($clearedCount -gt 0) {
            Write-Log "Cache cleared successfully ($clearedCount locations, $errorCount errors)" "INFO"
            return $true
        } else {
            Write-Log "No cache locations cleared" "WARN"
            return $false
        }
    } catch {
        Write-Log "Failed to clear cache: $_" "ERROR"
        return $false
    }
}

# Main polling loop - runs continuously, never exits
Write-Log "Starting notification polling (interval: $PollInterval seconds)" "INFO"
Write-Log "Agent will run continuously. Use Task Scheduler to stop." "INFO"

$pollCount = 0
while ($true) {
    $pollCount++
    try {
        # Query for pending notifications for this device and user
        $queryUrl = "$SupabaseUrl/rest/v1/user_notifications?device_hostname=eq.$DeviceHostname&username=eq.$FullUsername&status=eq.pending&order=created_at.asc&limit=10"
        
        $notifications = Invoke-RestMethod -Uri $queryUrl -Method GET -Headers $headers -ErrorAction Stop
        
        if ($notifications -and $notifications.Count -gt 0) {
            Write-Log "Found $($notifications.Count) pending notification(s)" "INFO"
            
            foreach ($notification in $notifications) {
                try {
                    $notificationId = $notification.id
                    $notificationType = $notification.type
                    $payload = $notification.payload
                    
                    Write-Log "Processing notification $notificationId (type: $notificationType)" "INFO"
                    
                    $success = $false
                    
                    switch ($notificationType) {
                        "buzzer" {
                            $duration = if ($payload.duration) { [int]$payload.duration } else { 5 }
                            $success = Play-Buzzer -Duration $duration
                        }
                        "lock" {
                            Write-Log "Executing lock workstation from user notification agent" "INFO"
                            try {
                                Start-Process -FilePath "rundll32.exe" -ArgumentList "user32.dll,LockWorkStation"
                                $success = $true
                            } catch {
                                Write-Log "Failed to lock workstation: $_" "ERROR"
                                $success = $false
                            }
                        }
                        "unlock" {
                            $success = Unlock-Device
                        }
                        "clear_cache" {
                            $success = Clear-DeviceCache
                        }
                        "toast" {
                            $title = if ($payload.title) { $payload.title } else { "VigyanShaala MDM" }
                            $message = if ($payload.message) { $payload.message } else { $payload }
                            $success = Show-ToastNotification -Title $title -Message $message
                        }
                        default {
                            Write-Log "Unknown notification type: $notificationType" "WARN"
                            $success = $false
                        }
                    }
                    
                    # Mark notification as processed
                    $updateUrl = "$SupabaseUrl/rest/v1/user_notifications?id=eq.$notificationId"
                    $updateBody = @{
                        status = if ($success) { "completed" } else { "failed" }
                        processed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    } | ConvertTo-Json
                    
                    try {
                        Invoke-RestMethod -Uri $updateUrl -Method PATCH -Headers $headers -Body $updateBody -ErrorAction Stop | Out-Null
                        Write-Log "Notification $notificationId marked as $(if ($success) { 'completed' } else { 'failed' })" "INFO"
                    } catch {
                        Write-Log "Failed to update notification status: $_" "ERROR"
                    }
                } catch {
                    Write-Log "Error processing individual notification: $_" "ERROR"
                    # Continue to next notification, don't exit
                }
            }
        } else {
            # Log every 60 polls (5 min) to show it's still running
            if ($pollCount % 60 -eq 0) {
                Write-Log "Polling active (poll #$pollCount, no pending notifications)" "DEBUG"
            }
        }
    } catch {
        $errorMessage = $_.Exception.Message
        if ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                $errorMessage += " - Response: $responseBody"
            } catch {
                # Ignore stream reading errors
            }
        }
        Write-Log "Error polling notifications: $errorMessage" "ERROR"
        Write-Log "Continuing to poll despite error..." "INFO"
        # Don't exit - continue polling
    }
    
    # Wait before next poll (always continue, never exit)
    try {
        Start-Sleep -Seconds $PollInterval
    } catch {
        Write-Log "Sleep interrupted, continuing..." "WARN"
        # Continue even if sleep is interrupted
    }
}

