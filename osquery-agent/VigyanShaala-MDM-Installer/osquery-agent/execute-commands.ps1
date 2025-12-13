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

# Function to queue buzz command for user-session agent
function Buzz-Device {
    param([int]$Duration = 5)
    
    Write-Host "Queueing buzz command for user-session agent..." -ForegroundColor Yellow
    try {
        # Get logged-in user (normalize to match user agent format)
        $loggedInUser = (Get-WmiObject -Class Win32_ComputerSystem).Username
        if (-not $loggedInUser) {
            Write-Warning "No logged-in user found for buzz command"
            return $false
        }
        
        # Normalize username format (domain\user or just user) to match user agent
        # User agent uses: domain\user if domain exists, else just user
        $normalizedUsername = $loggedInUser
        
        # Write notification to user_notifications table for user-session agent to process
        $headers = @{
            "apikey" = $SupabaseKey
            "Authorization" = "Bearer $SupabaseKey"
            "Content-Type" = "application/json"
            "Prefer" = "return=representation"
        }
        
        $body = @{
            device_hostname = $DeviceHostname
            username = $normalizedUsername
            type = "buzzer"
            payload = @{
                duration = $Duration
            }
            status = "pending"
        } | ConvertTo-Json -Depth 10
        
        $notificationUrl = "$SupabaseUrl/rest/v1/user_notifications"
        $response = Invoke-RestMethod -Uri $notificationUrl -Method POST -Headers $headers -Body $body -ErrorAction Stop
        
        Write-Host "Buzz command queued for user-session agent (notification ID: $($response.id))" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Failed to queue buzz command: $_"
        return $false
    }
}

# Function to queue toast notification for user-session agent
function Show-ToastNotification {
    param([string]$Title, [string]$Message)
    
    Write-Host "Queueing toast notification for user-session agent..." -ForegroundColor Yellow
    try {
        # Get logged-in user (normalize to match user agent format)
        $loggedInUser = (Get-WmiObject -Class Win32_ComputerSystem).Username
        if (-not $loggedInUser) {
            Write-Warning "No logged-in user found, using msg.exe fallback"
            msg.exe * "$Title - $Message" 2>$null
            return $true
        }
        
        # Normalize username format (domain\user or just user) to match user agent
        # User agent uses: domain\user if domain exists, else just user
        $normalizedUsername = $loggedInUser
        
        # Write notification to user_notifications table for user-session agent to process
        $headers = @{
            "apikey" = $SupabaseKey
            "Authorization" = "Bearer $SupabaseKey"
            "Content-Type" = "application/json"
            "Prefer" = "return=representation"
        }
        
        $body = @{
            device_hostname = $DeviceHostname
            username = $normalizedUsername
            type = "toast"
            payload = @{
                title = $Title
                message = $Message
            }
            status = "pending"
        } | ConvertTo-Json -Depth 10
        
        $notificationUrl = "$SupabaseUrl/rest/v1/user_notifications"
        $response = Invoke-RestMethod -Uri $notificationUrl -Method POST -Headers $headers -Body $body -ErrorAction Stop
        
        Write-Host "Toast notification queued for user-session agent (notification ID: $($response.id))" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Failed to queue toast notification: $_"
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
    
    Write-Host "Querying broadcast messages with hostname: '$DeviceHostname'" -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $messageUrl -Method GET -Headers $headers
        
        # If no results with exact match, try case-insensitive search
        if (-not $response -or $response.Count -eq 0) {
            Write-Host "No broadcast messages found with exact hostname match, trying case-insensitive search..." -ForegroundColor Yellow
            $allMessagesUrl = "$SupabaseUrl/rest/v1/device_commands?command_type=eq.broadcast_message&status=eq.pending&order=created_at.asc&select=*"
            $allMessages = Invoke-RestMethod -Uri $allMessagesUrl -Method GET -Headers $headers
            if ($allMessages) {
                $response = $allMessages | Where-Object { $_.device_hostname -and $_.device_hostname.Trim().ToUpper() -eq $DeviceHostname }
                if ($response) {
                    $response = @($response)  # Ensure it's an array
                    Write-Host "Found $($response.Count) broadcast message(s) with case-insensitive match" -ForegroundColor Green
                }
            }
        }
        
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
