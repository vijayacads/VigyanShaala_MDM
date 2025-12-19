# Realtime Command Listener
# Connects to Supabase Realtime via WebSocket to receive instant command notifications
# Replaces polling with push-based command processing

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY,
    [string]$DeviceHostname = $env:COMPUTERNAME,
    [string]$LogFile = "$env:TEMP\VigyanShaala-RealtimeListener.log"
)

# Normalize hostname
$DeviceHostname = $DeviceHostname.Trim().ToUpper()

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    } catch {}
    if ([Environment]::UserInteractive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "INFO" { "Green" }
            "DEBUG" { "Gray" }
            default { "White" }
        }
        Write-Host $logMessage -ForegroundColor $color
    }
}

Write-Log "Realtime Command Listener starting" "INFO"
Write-Log "Device: $DeviceHostname" "INFO"

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Log "Supabase URL and Key must be provided" "ERROR"
    exit 1
}

# Extract project ref from URL (e.g., https://abc123.supabase.co -> abc123)
$projectRef = ($SupabaseUrl -replace '^https://', '' -replace '\.supabase\.co/?$', '').Split('.')[0]
$realtimeUrl = "wss://$projectRef.supabase.co/realtime/v1/websocket?apikey=$SupabaseKey&vsn=1.0.0"

Write-Log "Realtime WebSocket URL: wss://$projectRef.supabase.co/realtime/v1/websocket" "INFO"

# Load command processing functions from execute-commands.ps1
$executeCommandsScript = Join-Path $PSScriptRoot "execute-commands.ps1"
if (-not (Test-Path $executeCommandsScript)) {
    $executeCommandsScript = "C:\Program Files\osquery\execute-commands.ps1"
}

if (-not (Test-Path $executeCommandsScript)) {
    Write-Log "execute-commands.ps1 not found. Cannot process commands." "ERROR"
    exit 1
}

# Import functions from execute-commands.ps1
# Read file line by line, skip param/validation, extract only functions
try {
    $allLines = Get-Content $executeCommandsScript
    $functionLines = @()
    $inFunctions = $false
    
    foreach ($line in $allLines) {
        # Stop at "# Main execution"
        if ($line -match '^\s*#\s*Main execution') {
            break
        }
        
        # Skip everything until we find the first function
        if (-not $inFunctions) {
            if ($line -match '^\s*function\s+\w+') {
                $inFunctions = $true
            } else {
                continue
            }
        }
        
        # Once we're in functions section, collect all lines
        if ($inFunctions) {
            $functionLines += $line
        }
    }
    
    if ($functionLines.Count -gt 0) {
        # Set variables in current scope for functions to use
        $script:SupabaseUrl = $SupabaseUrl
        $script:SupabaseKey = $SupabaseKey
        $script:DeviceHostname = $DeviceHostname
        
        # Execute the function definitions
        $functionsCode = $functionLines -join "`r`n"
        . ([scriptblock]::Create($functionsCode))
        
        Write-Log "Functions imported successfully from execute-commands.ps1" "INFO"
    } else {
        Write-Log "No functions found in execute-commands.ps1" "WARN"
    }
} catch {
    Write-Log "Error importing functions: $_" "ERROR"
    Write-Log "Some command functions may not be available" "WARN"
}

# Function to process command from WebSocket notification
function Process-CommandFromRealtime {
    param($commandData)
    
    Write-Log "Received command notification: $($commandData.command_type) (ID: $($commandData.id))" "INFO"
    
    # Verify it's for this device (case-insensitive)
    $cmdHostname = if ($commandData.device_hostname) { $commandData.device_hostname.Trim().ToUpper() } else { "" }
    if ($cmdHostname -ne $DeviceHostname) {
        Write-Log "Command is for different device: $cmdHostname (ignoring)" "WARN"
        return
    }
    
    # Check if command is pending
    if ($commandData.status -ne "pending") {
        Write-Log "Command status is not pending: $($commandData.status) (ignoring)" "WARN"
        return
    }
    
    # Process based on command type
    $headers = @{
        "apikey" = $SupabaseKey
        "Authorization" = "Bearer $SupabaseKey"
        "Content-Type" = "application/json"
    }
    
    $success = $false
    $errorMsg = $null
    
    switch ($commandData.command_type) {
        "lock" {
            Write-Log "Queueing lock command for user-session agent" "INFO"
            $success = Lock-Device
        }
        "unlock" {
            Write-Log "Queueing unlock command for user-session agent" "INFO"
            $success = Unlock-Device
        }
        "clear_cache" {
            Write-Log "Queueing clear_cache command for user-session agent" "INFO"
            $success = Clear-DeviceCache
        }
        "buzz" {
            Write-Log "Queueing buzz command for user-session agent" "INFO"
            $duration = if ($commandData.duration) { $commandData.duration } else { 5 }
            $success = Buzz-Device -Duration $duration
        }
        "broadcast_message" {
            Write-Log "Processing broadcast message" "INFO"
            if ($commandData.message) {
                Show-BroadcastMessage -Message $commandData.message -MessageId $commandData.id
                $success = $true
            }
        }
    }
    
    # Update command status
    if ($commandData.command_type -ne "broadcast_message") {
        $updateUrl = "$SupabaseUrl/rest/v1/device_commands?id=eq.$($commandData.id)"
        $updateBody = @{
            status = if ($success) { "completed" } else { "failed" }
            executed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            error_message = $errorMsg
        } | ConvertTo-Json
        
        try {
            Invoke-RestMethod -Uri $updateUrl -Method PATCH -Headers $headers -Body $updateBody | Out-Null
            Write-Log "Command $($commandData.id) marked as $(if ($success) { 'completed' } else { 'failed' })" "INFO"
        } catch {
            Write-Log "Failed to update command status: $_" "ERROR"
        }
    }
}

# WebSocket connection management
$script:webSocket = $null
$script:cancellationTokenSource = New-Object System.Threading.CancellationTokenSource
$script:reconnectDelay = 5
$script:maxReconnectDelay = 300
$script:messageRef = 1

# Helper to send WebSocket messages
function Send-WebSocketMessage {
    param(
        [System.Net.WebSockets.ClientWebSocket]$ws,
        [hashtable]$message
    )
    
    try {
        $message.ref = $script:messageRef++
        $jsonMessage = $message | ConvertTo-Json -Compress -Depth 10
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonMessage)
        $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
        $sendTask = $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $script:cancellationTokenSource.Token)
        $sendTask.Wait(5000)
        return $sendTask.IsCompletedSuccessfully
    } catch {
        Write-Log "Failed to send WebSocket message: $_" "ERROR"
        return $false
    }
}

# Connect to Supabase Realtime WebSocket
function Connect-WebSocket {
    try {
        Write-Log "Connecting to Supabase Realtime..." "INFO"
        Write-Log "Connecting to: $realtimeUrl" "INFO"
        
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $uri = [System.Uri]::new($realtimeUrl)
        
        # Connect with timeout and error handling
        try {
            $connectTask = $ws.ConnectAsync($uri, $script:cancellationTokenSource.Token)
            $completed = $connectTask.Wait(15000)  # 15 second timeout
            
            if (-not $completed -or $ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                throw "Connection timeout or failed"
            }
        } catch {
            Write-Log "Connect exception (base): $($_.Exception.GetBaseException().Message)" "ERROR"
            Write-Log "Connect exception (full): $($_.Exception.ToString())" "ERROR"
            throw
        }
        
        Write-Log "WebSocket connected successfully" "INFO"
        
        # Join the channel with postgres_changes subscription in config
        $channelName = "realtime:public:device_commands"
        $joinMessage = @{
            topic = $channelName
            event = "phx_join"
            payload = @{
                config = @{
                    broadcast = @{ self = $false }
                    presence  = @{ key = "" }
                    postgres_changes = @(
                        @{
                            event = "INSERT"
                            schema = "public"
                            table = "device_commands"
                            # No filter initially - we filter in Process-CommandFromRealtime
                            # Can add filter later if needed: filter = "device_hostname=eq.$DeviceHostname"
                        }
                    )
                }
            }
            ref = $script:messageRef
        }
        
        if (-not (Send-WebSocketMessage -ws $ws -message $joinMessage)) {
            throw "Failed to send join message"
        }
        
        Write-Log "Sent channel join message with postgres_changes subscription" "INFO"
        
        # Send Realtime auth frame (access_token)
        $accessTokenMessage = @{
            topic = $channelName
            event = "access_token"
            payload = @{
                access_token = $SupabaseKey   # the anon key
            }
            ref = $script:messageRef
        }
        Send-WebSocketMessage -ws $ws -message $accessTokenMessage | Out-Null
        Write-Log "Sent access_token message" "INFO"
        
        # Wait a moment for subscription confirmation
        Start-Sleep -Milliseconds 1000
        
        return $ws
    } catch {
        Write-Log "Failed to connect: $_" "ERROR"
        if ($ws) {
            try { $ws.Dispose() } catch {}
        }
        return $null
    }
}

# Receive messages loop (simple, no over-engineering)
function Receive-Messages {
    param([System.Net.WebSockets.ClientWebSocket]$ws)
    
    $buffer = New-Object byte[] 8192
    $fullMessage = New-Object System.Collections.ArrayList
    
    while ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open -and -not $script:cancellationTokenSource.Token.IsCancellationRequested) {
        try {
            # Check connection state before operations
            if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-Log "WebSocket state changed to: $($ws.State)" "WARN"
                break
            }
            
            $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$buffer)
            $receiveTask = $ws.ReceiveAsync($segment, $script:cancellationTokenSource.Token)
            
            # Wait with fixed 60s timeout
            $completed = $receiveTask.Wait(60000)
            
            # Check state after receive attempt
            if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Closed) {
                Write-Log "WebSocket state is Closed" "WARN"
                break
            }
            
            if (-not $completed) {
                # Timeout - send heartbeat and continue
                $heartbeat = @{
                    topic = "phoenix"
                    event = "heartbeat"
                    payload = @{}
                    ref = $script:messageRef
                }
                if (Send-WebSocketMessage -ws $ws -message $heartbeat) {
                    Write-Log "Heartbeat sent (timeout)" "INFO"
                }
                continue
            }
            
            if ($receiveTask.Result.Count -gt 0) {
                $receivedBytes = $buffer[0..($receiveTask.Result.Count - 1)]
                $fullMessage.AddRange($receivedBytes)
                
                if ($receiveTask.Result.EndOfMessage) {
                    $messageText = [System.Text.Encoding]::UTF8.GetString($fullMessage.ToArray())
                    $fullMessage.Clear()
                    
                    # Process the message
                    Process-WebSocketMessage -MessageText $messageText
                }
            } else {
                # No data received but task completed - might be a close frame
                if ($receiveTask.Result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                    Write-Log "Received close frame from server" "WARN"
                    break
                }
            }
        } catch {
            if ($_.Exception.InnerException -is [System.OperationCanceledException]) {
                Write-Log "Receive cancelled" "INFO"
                break
            }
            if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Closed) {
                Write-Log "WebSocket connection closed: $($_.Exception.Message)" "WARN"
                break
            }
            Write-Log "Error receiving message: $_" "ERROR"
            Start-Sleep -Seconds 1
        }
    }
}

# Process WebSocket messages (correct event handling)
function Process-WebSocketMessage {
    param([string]$MessageText)
    
    try {
        # Always log the raw frame
        Write-Log "RAW WS: $MessageText" "DEBUG"
        
        # Parse JSON once
        $message = $MessageText | ConvertFrom-Json
        $topEvent = $message.event
        
        # Handle phx_reply (acknowledgments)
        if ($topEvent -eq "phx_reply") {
            Write-Log "phx_reply: status=$($message.payload.status) response=$($message.payload.response)" "INFO"
            return
        }
        
        # Handle postgres_changes (INSERT events)
        # IMPORTANT: Check event = "postgres_changes" and then payload.data.type = "INSERT"
        # Do NOT check event = "INSERT" at the top level - this was a key bug in the old version
        if ($topEvent -eq "postgres_changes" -and $message.payload -and $message.payload.data) {
            $data = $message.payload.data
            Write-Log "postgres_changes: type=$($data.type) table=$($data.table)" "INFO"
            
            if ($data.type -eq "INSERT" -and $data.table -eq "device_commands") {
                $newRecord = $data.record
                if ($newRecord) {
                    Write-Log "Processing INSERT command: $($newRecord.command_type) (ID: $($newRecord.id))" "INFO"
                    Process-CommandFromRealtime -commandData $newRecord
                } else {
                    Write-Log "INSERT event has no record data" "WARN"
                }
            } elseif ($data.type -eq "UPDATE" -and $data.table -eq "device_commands") {
                # Ignore UPDATE events (we only process INSERT)
                Write-Log "Ignoring UPDATE event for device_commands" "DEBUG"
            }
            return
        }
        
        # Handle heartbeat responses
        if ($topEvent -eq "heartbeat") {
            # Connection is alive
            return
        }
        
        # Handle phx_close
        if ($topEvent -eq "phx_close") {
            Write-Log "Received phx_close event" "WARN"
        }
        
    } catch {
        Write-Log "Error processing message: $_" "ERROR"
        Write-Log "Message was: $MessageText" "DEBUG"
    }
}

# Main connection loop with reconnection
$reconnectCount = 0
while (-not $script:cancellationTokenSource.Token.IsCancellationRequested) {
    $script:webSocket = Connect-WebSocket
    
    if ($script:webSocket) {
        $reconnectCount = 0
        $script:reconnectDelay = 5
        Write-Log "Connection established. Listening for commands..." "INFO"
        
        # Start receiving messages (blocks until connection closes)
        Receive-Messages -ws $script:webSocket
        
        # Connection closed - cleanup
        if ($script:webSocket.State -ne [System.Net.WebSockets.WebSocketState]::Closed) {
            try {
                $closeTask = $script:webSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Reconnecting", $script:cancellationTokenSource.Token)
                $closeTask.Wait(5000)
            } catch {}
        }
        $script:webSocket.Dispose()
        $script:webSocket = $null
        
        Write-Log "Connection closed. Will attempt reconnection..." "WARN"
    } else {
        $reconnectCount++
        Write-Log "Connection failed. Retrying in $($script:reconnectDelay) seconds... (Attempt $reconnectCount)" "WARN"
        Start-Sleep -Seconds $script:reconnectDelay
        
        # Exponential backoff (max 5 minutes)
        $script:reconnectDelay = [Math]::Min($script:reconnectDelay * 2, $script:maxReconnectDelay)
    }
}

Write-Log "Realtime listener stopped" "INFO"
