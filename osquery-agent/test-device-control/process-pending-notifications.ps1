# Process Pending Notifications - Run user agent once to process queued notifications
# This will check for pending buzz/toast notifications and execute them immediately

$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co"
$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ"
$DeviceHostname = $env:COMPUTERNAME.Trim().ToUpper()

# Use same format as execute-commands.ps1 (WMI)
$FullUsername = (Get-WmiObject -Class Win32_ComputerSystem).Username
if (-not $FullUsername) {
    $CurrentUsername = $env:USERNAME
    $CurrentDomain = $env:USERDOMAIN
    $FullUsername = if ($CurrentDomain -and $CurrentDomain -ne $env:COMPUTERNAME) {
        "$CurrentDomain\$CurrentUsername"
    } else {
        $CurrentUsername
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Process Pending Notifications" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Device: $DeviceHostname" -ForegroundColor Yellow
Write-Host "User: $FullUsername" -ForegroundColor Yellow
Write-Host ""

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

# Check for pending notifications
Write-Host "Checking for pending notifications..." -ForegroundColor Yellow

$queryUrl = "$SupabaseUrl/rest/v1/user_notifications?device_hostname=eq.$DeviceHostname"
$queryUrl = $queryUrl + [char]38 + "username=eq.$FullUsername"
$queryUrl = $queryUrl + [char]38 + 'status=eq.pending'
$queryUrl = $queryUrl + [char]38 + 'order=created_at.asc'
$queryUrl = $queryUrl + [char]38 + 'limit=10'

try {
    $notifications = Invoke-RestMethod -Uri $queryUrl -Method GET -Headers $headers
    
    if (-not $notifications -or $notifications.Count -eq 0) {
        Write-Host "No pending notifications found" -ForegroundColor Gray
        exit 0
    }
    
    Write-Host "Found $($notifications.Count) pending notification(s)" -ForegroundColor Green
    Write-Host ""
    
    # Process each notification
    foreach ($notification in $notifications) {
        $notificationId = $notification.id
        $notificationType = $notification.type
        $payload = $notification.payload
        
        Write-Host "Processing: $notificationType (ID: $notificationId)" -ForegroundColor Yellow
        
        $success = $false
        
        switch ($notificationType) {
            "buzzer" {
                $duration = if ($payload.duration) { [int]$payload.duration } else { 5 }
                Write-Host "  Playing buzzer for $duration seconds..." -ForegroundColor Gray
                try {
                    $endTime = (Get-Date).AddSeconds($duration)
                    $beepCount = 0
                    while ((Get-Date) -lt $endTime) {
                        [console]::beep(800, 500)
                        Start-Sleep -Milliseconds 500
                        $beepCount++
                    }
                    Write-Host "  Buzzer played ($beepCount beeps)" -ForegroundColor Green
                    $success = $true
                } catch {
                    Write-Host "  Failed: $_" -ForegroundColor Red
                }
            }
            "toast" {
                $title = if ($payload.title) { $payload.title } else { "VigyanShaala MDM" }
                $message = if ($payload.message) { $payload.message } else { $payload }
                Write-Host "  Showing toast: $title - $message" -ForegroundColor Gray
                try {
                    Add-Type -AssemblyName System.Runtime.WindowsRuntime
                    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
                    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
                    
                    $escapedTitle = $title -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
                    $escapedMessage = $message -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
                    
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
                    Write-Host "  Toast shown" -ForegroundColor Green
                    $success = $true
                } catch {
                    Write-Host "  Failed: $_" -ForegroundColor Red
                }
            }
        }
        
        # Mark as processed
        $updateUrl = "$SupabaseUrl/rest/v1/user_notifications?id=eq.$notificationId"
        $updateBody = @{
            status = if ($success) { "completed" } else { "failed" }
            processed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        } | ConvertTo-Json
        
        try {
            Invoke-RestMethod -Uri $updateUrl -Method PATCH -Headers $headers -Body $updateBody | Out-Null
            Write-Host "  Marked as $(if ($success) { 'completed' } else { 'failed' })" -ForegroundColor $(if ($success) { "Green" } else { "Red" })
        } catch {
            Write-Host "  Failed to update status: $_" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-Host "All notifications processed!" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""

