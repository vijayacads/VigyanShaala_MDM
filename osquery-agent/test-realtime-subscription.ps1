# Test Realtime Subscription
# Simple test script to verify Supabase Realtime WebSocket connection and subscription
# Mirrors the protocol handling from realtime-command-listener.ps1 for consistency

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Error "Supabase URL and Key must be provided"
    exit 1
}

# Extract project ref from URL
$projectRef = ($SupabaseUrl -replace '^https://', '' -replace '\.supabase\.co/?$', '').Split('.')[0]
$realtimeUrl = "wss://$projectRef.supabase.co/realtime/v1/websocket?apikey=$SupabaseKey&vsn=1.0.0"

Write-Host "Connecting to: $realtimeUrl" -ForegroundColor Cyan

$messageRef = 1

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
        $sendTask = $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None)
        $sendTask.Wait(5000)
        return $sendTask.IsCompletedSuccessfully
    } catch {
        Write-Host "Failed to send message: $_" -ForegroundColor Red
        return $false
    }
}

try {
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $uri = [System.Uri]::new($realtimeUrl)
    
    Write-Host "Connecting..." -ForegroundColor Yellow
    $connectTask = $ws.ConnectAsync($uri, [System.Threading.CancellationToken]::None)
    $connectTask.Wait(15000)
    
    if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        Write-Host "Connection failed. State: $($ws.State)" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Connected successfully" -ForegroundColor Green
    
    # Join channel with postgres_changes subscription (same as main listener)
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
                    }
                )
            }
        }
        ref = $messageRef
    }
    
    if (-not (Send-WebSocketMessage -ws $ws -message $joinMessage)) {
        Write-Host "Failed to send join message" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Sent channel join message with postgres_changes subscription" -ForegroundColor Green
    
    # Send access_token
    $accessTokenMessage = @{
        topic = $channelName
        event = "access_token"
        payload = @{
            access_token = $SupabaseKey
        }
        ref = $messageRef
    }
    Send-WebSocketMessage -ws $ws -message $accessTokenMessage | Out-Null
    Write-Host "Sent access_token message" -ForegroundColor Green
    
    Write-Host "`nListening for events... (Press Ctrl+C to stop)" -ForegroundColor Cyan
    Write-Host "Insert a command into device_commands table to test.`n" -ForegroundColor Yellow
    
    # Simple receive loop (fixed 30s timeout)
    $buffer = New-Object byte[] 8192
    $fullMessage = New-Object System.Collections.ArrayList
    
    while ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
        try {
            $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$buffer)
            $receiveTask = $ws.ReceiveAsync($segment, [System.Threading.CancellationToken]::None)
            $completed = $receiveTask.Wait(30000)  # 30 second timeout
            
            if (-not $completed) {
                # Timeout - send heartbeat
                $heartbeat = @{
                    topic = "phoenix"
                    event = "heartbeat"
                    payload = @{}
                    ref = $messageRef
                }
                Send-WebSocketMessage -ws $ws -message $heartbeat | Out-Null
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Heartbeat sent" -ForegroundColor Gray
                continue
            }
            
            if ($receiveTask.Result.Count -gt 0) {
                $receivedBytes = $buffer[0..($receiveTask.Result.Count - 1)]
                $fullMessage.AddRange($receivedBytes)
                
                if ($receiveTask.Result.EndOfMessage) {
                    $messageText = [System.Text.Encoding]::UTF8.GetString($fullMessage.ToArray())
                    $fullMessage.Clear()
                    
                    # Parse and display message (same protocol handling as main listener)
                    try {
                        $message = $messageText | ConvertFrom-Json
                        $topEvent = $message.event
                        
                        $timestamp = Get-Date -Format "HH:mm:ss"
                        
                        if ($topEvent -eq "phx_reply") {
                            Write-Host "[$timestamp] Event: phx_reply, Topic: $($message.topic)" -ForegroundColor Cyan
                            Write-Host "  -> Reply: status=$($message.payload.status)" -ForegroundColor Gray
                        }
                        elseif ($topEvent -eq "postgres_changes" -and $message.payload -and $message.payload.data) {
                            $data = $message.payload.data
                            Write-Host "[$timestamp] Event: postgres_changes, Type: $($data.type), Table: $($data.table)" -ForegroundColor Green
                            
                            if ($data.type -eq "INSERT" -and $data.table -eq "device_commands" -and $data.record) {
                                $record = $data.record
                                Write-Host "  -> Command: $($record.command_type), Device: $($record.device_hostname), ID: $($record.id)" -ForegroundColor Yellow
                            }
                        }
                        elseif ($topEvent -eq "heartbeat") {
                            Write-Host "[$timestamp] Event: heartbeat" -ForegroundColor Gray
                        }
                        elseif ($topEvent -eq "phx_close") {
                            Write-Host "[$timestamp] Event: phx_close" -ForegroundColor Red
                            break
                        }
                        else {
                            Write-Host "[$timestamp] Event: $topEvent, Topic: $($message.topic)" -ForegroundColor White
                        }
                    } catch {
                        Write-Host "[$timestamp] Error parsing message: $_" -ForegroundColor Red
                        Write-Host "Raw: $messageText" -ForegroundColor DarkGray
                    }
                }
            }
            else {
                if ($receiveTask.Result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                    Write-Host "Received close frame from server" -ForegroundColor Red
                    break
                }
            }
        } catch {
            if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Closed) {
                Write-Host "Connection closed: $($_.Exception.Message)" -ForegroundColor Red
                break
            }
            Write-Host "Error: $_" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
} finally {
    if ($ws) {
        try {
            if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                $closeTask = $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Done", [System.Threading.CancellationToken]::None)
                $closeTask.Wait(5000)
            }
            $ws.Dispose()
        } catch {}
    }
    Write-Host "`nDisconnected" -ForegroundColor Yellow
}

