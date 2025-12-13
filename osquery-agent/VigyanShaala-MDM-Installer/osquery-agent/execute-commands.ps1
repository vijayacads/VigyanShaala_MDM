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

# Function to execute buzz command
function Buzz-Device {
    param([int]$Duration = 5)
    
    Write-Host "Buzzing device for $Duration seconds..." -ForegroundColor Yellow
    try {
        $endTime = (Get-Date).AddSeconds($Duration)
        while ((Get-Date) -lt $endTime) {
            [console]::beep(800, 500)
            Start-Sleep -Milliseconds 500
        }
        return $true
    } catch {
        Write-Error "Failed to buzz device: $_"
        return $false
    }
}

# Function to display broadcast message
function Show-BroadcastMessage {
    param([string]$Message)
    
    Write-Host "Broadcast Message: $Message" -ForegroundColor Cyan
    
    # Try to use BurntToast if available
    if (Get-Command New-BurntToastNotification -ErrorAction SilentlyContinue) {
        New-BurntToastNotification -Text "MDM Broadcast", $Message -AppId "VigyanShaala MDM"
    } else {
        # Fallback to PowerShell popup
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Message, "MDM Broadcast Message", "OK", "Information")
    }
}

# Function to check and execute commands
function Process-Commands {
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
        "Content-Type" = "application/json"
    }
    
    # Get pending commands for this device
    $commandUrl = "$SupabaseUrl/rest/v1/device_commands?device_hostname=eq.$DeviceHostname&command_type=in.(lock,unlock,clear_cache,buzz)&status=eq.pending&order=created_at.asc&limit=1"
    
    try {
        $response = Invoke-RestMethod -Uri $commandUrl -Method GET -Headers $headers
        
        if ($response -and $response.Count -gt 0) {
            $command = $response[0]
            Write-Host "Processing command: $($command.command_type)" -ForegroundColor Green
            
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
            
            Invoke-RestMethod -Uri $updateUrl -Method PATCH -Headers $headers -Body $updateBody | Out-Null
        }
    } catch {
        Write-Error "Error processing commands: $_"
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
            foreach ($msg in $response) {
                if ($msg.message) {
                    Show-BroadcastMessage -Message $msg.message
                    
                    # Mark as dismissed
                    $updateUrl = "$SupabaseUrl/rest/v1/device_commands?id=eq.$($msg.id)"
                    $updateBody = @{
                        status = "dismissed"
                        executed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    } | ConvertTo-Json
                    
                    Invoke-RestMethod -Uri $updateUrl -Method PATCH -Headers $headers -Body $updateBody | Out-Null
                }
            }
        }
    } catch {
        Write-Error "Error processing broadcast messages: $_"
    }
}

# Main polling loop
Write-Host "Starting command/message polling for device: $DeviceHostname" -ForegroundColor Green
Write-Host "Polling every 30 seconds..." -ForegroundColor Gray

while ($true) {
    try {
        Process-Commands
        Process-BroadcastMessages
    } catch {
        Write-Error "Error in polling loop: $_"
    }
    
    Start-Sleep -Seconds 30
}
