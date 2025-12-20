# Check what notifications exist and what username format is used

$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co"
$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbWNqZXpwbXl2cGlhc2Zyd2htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzOTQ2NzQsImV4cCI6MjA4MDk3MDY3NH0.LNeLEQs2K1AXyTG2vlCHyfRLpavFBSGgqjtwLoXdyMQ"
$DeviceHostname = $env:COMPUTERNAME.Trim().ToUpper()

Write-Host ""
Write-Host "Checking username formats..." -ForegroundColor Cyan
Write-Host ""

# Check what execute-commands.ps1 uses
$wmiUser = (Get-WmiObject -Class Win32_ComputerSystem).Username
Write-Host "WMI Username (used by execute-commands): $wmiUser" -ForegroundColor Yellow

# Check what user-notify-agent uses
$CurrentUsername = $env:USERNAME
$CurrentDomain = $env:USERDOMAIN
$FullUsername = if ($CurrentDomain -and $CurrentDomain -ne $env:COMPUTERNAME) {
    "$CurrentDomain\$CurrentUsername"
} else {
    $CurrentUsername
}
Write-Host "User Agent Username: $FullUsername" -ForegroundColor Yellow
Write-Host ""

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
}

# Check all pending notifications for this device
Write-Host "Checking all pending notifications for device: $DeviceHostname" -ForegroundColor Cyan
$queryUrl = "$SupabaseUrl/rest/v1/user_notifications?device_hostname=eq.$DeviceHostname"
$queryUrl = $queryUrl + [char]38 + 'status=eq.pending'
$queryUrl = $queryUrl + [char]38 + 'select=id,username,type,status,created_at'

try {
    $allNotifications = Invoke-RestMethod -Uri $queryUrl -Method GET -Headers $headers
    
    if ($allNotifications -and $allNotifications.Count -gt 0) {
        Write-Host "Found $($allNotifications.Count) pending notification(s):" -ForegroundColor Green
        foreach ($notif in $allNotifications) {
            Write-Host "  ID: $($notif.id)" -ForegroundColor Gray
            Write-Host "    Username: $($notif.username)" -ForegroundColor Gray
            Write-Host "    Type: $($notif.type)" -ForegroundColor Gray
            Write-Host "    Created: $($notif.created_at)" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "No pending notifications found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""




