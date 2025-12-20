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
$projectRef = ($SupabaseUrl -replace 'https://', '' -replace '.supabase.co', '').Split('.')[0]
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
# Based on Perplexity's analysis: skip everything until first function, then collect all
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
            Write-Log "Executing lock command" "INFO"
            $success = Lock-Device
        }
        "unlock" {
            Write-Log "Unlock requires user interaction" "WARN"
            $errorMsg = "Unlock requires user password/pin"
        }
        "clear_cache" {
            Write-Log "Executing clear_cache command" "INFO"
            $success = Clear-DeviceCache
        }
        "buzz" {
            Write-Log "Executing buzz command" "INFO"
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

function Connect-WebSocket {
    try {
        Write-Log "Connecting to Supabase Realtime..." "INFO"
        
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $uri = [System.Uri]::new($realtimeUrl)
        
        # Connect with timeout
        $connectTask = $ws.ConnectAsync($uri, $script:cancellationTokenSource.Token)
        $completed = $connectTask.Wait(15000)  # 15 second timeout
        
        if (-not $completed -or $ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            throw "Connection timeout or failed"
        }
        
        Write-Log "WebSocket connected successfully" "INFO"
        
        # Join the channel for device_commands table
        $channelName = "realtime:public:device_commands"
        $joinMessage = @{
            topic = $channelName
            event = "phx_join"
            payload = @{
                config = @{
                    broadcast = @{
                        self = $false
                    }
                    presence = @{
                        key = ""
                    }
                }
            }
            ref = $script:messageRef
        }
        
        if (-not (Send-WebSocketMessage -ws $ws -message $joinMessage)) {
            throw "Failed to send join message"
        }
        
        Write-Log "Sent channel join message" "INFO"
        
        # Subscribe to postgres_changes for INSERT events
        # Note: No filter in subscription - we'll filter in code instead
        $subscribeRef = $script:messageRef
        $subscribeMessage = @{
            topic = $channelName
            event = "postgres_changes"
            payload = @{
                type = "postgres_changes"
                event = "INSERT"
                schema = "public"
                table = "device_commands"
                # No filter - will receive all INSERT events, filter in Process-CommandFromRealtime
            }
            ref = $subscribeRef
        }
        
        if (-not (Send-WebSocketMessage -ws $ws -message $subscribeMessage)) {
            throw "Failed to send subscription message"
        }
        
        Write-Log "Sent postgres_changes subscription (ref: $subscribeRef) - NO FILTER (will filter in code)" "INFO"
        
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

function Receive-Messages {
    param([System.Net.WebSockets.ClientWebSocket]$ws)
    
    $buffer = New-Object byte[] 8192
    $fullMessage = New-Object System.Collections.ArrayList
    $lastHeartbeat = Get-Date
    
    while ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open -and -not $script:cancellationTokenSource.Token.IsCancellationRequested) {
        try {
            # Check connection state before operations
            if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-Log "WebSocket state changed to: $($ws.State)" "WARN"
                break
            }
            
            # Send heartbeat every 25 seconds (before 30s timeout to prevent connection drop)
            $timeSinceLastHeartbeat = (Get-Date) - $lastHeartbeat
            if ($timeSinceLastHeartbeat -gt [TimeSpan]::FromSeconds(25)) {
                $heartbeat = @{
                    topic = "phoenix"
                    event = "heartbeat"
                    payload = @{}
                    ref = $script:messageRef
                }
                if (Send-WebSocketMessage -ws $ws -message $heartbeat) {
                    $lastHeartbeat = Get-Date
                    Write-Log "Heartbeat sent" "INFO"
                } else {
                    Write-Log "Failed to send heartbeat" "WARN"
                    # If heartbeat fails, connection might be dead
                    if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                        break
                    }
                }
            }
            
            # Calculate timeout for receive (ensure we check heartbeat before 30s)
            $timeUntilNextHeartbeat = [TimeSpan]::FromSeconds(25) - $timeSinceLastHeartbeat
            $receiveTimeout = [Math]::Min([Math]::Max($timeUntilNextHeartbeat.TotalMilliseconds, 5000), 25000)
            
            # Check state again before receive
            if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                break
            }
            
            $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$buffer)
            $receiveTask = $ws.ReceiveAsync($segment, $script:cancellationTokenSource.Token)
            
            # Wait with calculated timeout (max 25 seconds to allow heartbeat check)
            $completed = $receiveTask.Wait([int]$receiveTimeout)
            
            # Check state after receive attempt
            if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-Log "WebSocket connection closed during receive" "WARN"
                break
            }
            
            if (-not $completed) {
                continue  # Timeout, continue loop to check/send heartbeat
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
            if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-Log "WebSocket connection closed: $($_.Exception.Message)" "WARN"
                break
            }
            Write-Log "Error receiving message: $_" "ERROR"
            Start-Sleep -Seconds 1
        }
    }
}

function Process-WebSocketMessage {
    param([string]$MessageText)
    
    try {
        $message = $MessageText | ConvertFrom-Json
        
        # Log all received messages for debugging (except heartbeats to reduce noise)
        if ($message.event -ne "heartbeat") {
            $payloadEvent = if ($message.payload -and $message.payload.event) { $message.payload.event } else { "N/A" }
            Write-Log "WS message: event=$($message.event), topic=$($message.topic), payload.event=$payloadEvent" "DEBUG"
        }
        
        # Handle phx_reply (acknowledgments)
        if ($message.event -eq "phx_reply") {
            if ($message.payload.status -eq "ok") {
                # Check if this is for channel join or postgres_changes subscription
                if ($message.topic -match "realtime:public:device_commands") {
                    Write-Log "Subscription confirmed (ref: $($message.ref)) - topic: $($message.topic)" "INFO"
                    # Log subscription details if available
                    if ($message.payload.response) {
                        Write-Log "Subscription response: $($message.payload.response | ConvertTo-Json -Compress)" "INFO"
                    }
                }
            } else {
                Write-Log "Subscription error (ref: $($message.ref)): $($message.payload.response)" "WARN"
                if ($message.payload.response) {
                    Write-Log "Full error response: $($message.payload.response | ConvertTo-Json -Depth 5)" "ERROR"
                }
            }
            return
        }
        
        # Handle postgres_changes (INSERT events)
        # Supabase sends message.event = "postgres_changes", change type is in payload.event
        if ($message.event -eq "postgres_changes" -and $message.payload) {
            $changeType = $message.payload.event  # "INSERT" / "UPDATE" / "DELETE"
            $payloadKeys = $message.payload.PSObject.Properties.Name -join ', '
            Write-Log "postgres_changes event=$changeType, payload keys: $payloadKeys" "INFO"
            
            if ($changeType -eq "INSERT") {
                # The new record might be in payload.new, payload.record, or directly in payload
                $newRecord = if ($message.payload.new) { 
                    $message.payload.new 
                } elseif ($message.payload.record) {
                    $message.payload.record
                } else { 
                    $message.payload 
                }
                
                if ($newRecord -and $newRecord.command_type) {
                    Write-Log "Processing INSERT command: $($newRecord.command_type) (ID: $($newRecord.id))" "INFO"
                    Process-CommandFromRealtime -commandData $newRecord
                } else {
                    Write-Log "INSERT payload did not contain expected new record" "WARN"
                    Write-Log "Full payload: $($message.payload | ConvertTo-Json -Depth 10)" "DEBUG"
                }
            }
        }
        
        # Handle heartbeat responses
        if ($message.event -eq "heartbeat") {
            # Connection is alive
            return
        }
        
        # Handle phx_close
        if ($message.event -eq "phx_close") {
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


