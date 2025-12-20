# Device Control Method - WebSocket Realtime

## Overview
Device control commands (lock, unlock, clear cache, buzz, broadcast) are delivered to devices using **Supabase Realtime WebSocket** connections for instant, push-based command processing.

## Architecture

### Method: WebSocket Realtime (Push-Based)
- **Primary Method**: Supabase Realtime WebSocket connection
- **Protocol**: Phoenix Channels over WebSocket
- **Delivery**: Instant (real-time push)
- **Connection**: Persistent, continuous connection from device to Supabase

### How It Works

1. **Device Connection**
   - Each device establishes a WebSocket connection to Supabase Realtime on startup
   - Connection URL: `wss://[project].supabase.co/realtime/v1/websocket`
   - Authenticated using Supabase API key

2. **Subscription**
   - Device subscribes to `device_commands` table changes
   - Filters by `device_hostname` to receive only commands for that device
   - Listens for `INSERT` events (new commands)

3. **Command Processing**
   - When dashboard creates a command, Supabase Realtime pushes it instantly to the device
   - Device receives notification via WebSocket
   - Command is processed immediately (lock, clear cache, buzz, etc.)
   - Status updated in database (completed/failed)

4. **Reconnection**
   - Automatic reconnection with exponential backoff (5s → 300s max)
   - Continuous monitoring and heartbeat (every 30 seconds)
   - Logs connection status to `%TEMP%\VigyanShaala-RealtimeListener.log`

## Scheduled Task

**Task Name**: `VigyanShaala-MDM-RealtimeListener`
- **Trigger**: At system startup
- **Account**: SYSTEM
- **Behavior**: Runs continuously, restarts on failure
- **Script**: `realtime-command-listener.ps1`

## Why This Method?

### Advantages
- ✅ **Instant Delivery**: Commands processed immediately (no polling delay)
- ✅ **Efficient**: 71% fewer requests vs polling (for 200 devices: 28,800/day → 8,400/day)
- ✅ **Scalable**: Works efficiently with 200+ devices
- ✅ **Real-time**: True push-based architecture
- ✅ **Reduced Load**: Minimal server load, only active when commands are sent

### Comparison to Polling
| Aspect | Polling (Old) | WebSocket (Current) |
|--------|---------------|---------------------|
| **Delivery Time** | 1-5 minutes | Instant (< 1 second) |
| **Requests/Day** | 28,800 (200 devices) | 8,400 (200 devices) |
| **Server Load** | High (constant polling) | Low (only on events) |
| **Network Usage** | Continuous | Event-driven |
| **Complexity** | Low | Medium |

## Requirements

1. **Supabase Realtime Enabled**
   - Must enable Realtime for `device_commands` table in Supabase Dashboard
   - Path: Database → Realtime → Enable for `device_commands`

2. **Network Access**
   - Device must have outbound WebSocket (WSS) access to Supabase
   - Port 443 (HTTPS/WSS) must be open

3. **PowerShell .NET Support**
   - Uses `System.Net.WebSockets.ClientWebSocket` (.NET Framework 4.5+)
   - Available on Windows 8+ / Windows Server 2012+

## Command Types Supported

- **lock**: Lock the device screen
- **unlock**: Unlock (requires user interaction)
- **clear_cache**: Clear browser and temp caches
- **buzz**: Play system sound (via user session agent)
- **broadcast_message**: Display toast notification + add to chat

## Implementation Files

- **`realtime-command-listener.ps1`**: WebSocket client and command processor
- **`execute-commands.ps1`**: Command execution functions (imported by listener)
- **`user-notify-agent.ps1`**: User session agent for buzz/toast (runs separately)

## Monitoring

- **Logs**: `%TEMP%\VigyanShaala-RealtimeListener.log`
- **Task Status**: Check via `Get-ScheduledTask -TaskName "VigyanShaala-MDM-RealtimeListener"`
- **Connection Status**: Logged in realtime listener log file

## Fallback

If WebSocket connection fails:
- Automatic reconnection attempts (exponential backoff)
- Commands may be delayed until reconnection succeeds
- No polling fallback (removed for efficiency)

## Future Considerations

- Could add health check endpoint for connection status
- Could add dashboard indicator for WebSocket connection state
- Could implement command queue for offline devices (future enhancement)




