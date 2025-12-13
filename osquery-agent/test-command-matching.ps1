# Diagnostic script to test command matching
# Run this on the device to verify hostname matching

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY
)

if (-not $SupabaseUrl -or -not $SupabaseKey) {
    Write-Error "Supabase URL and Key must be provided"
    exit 1
}

$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
}

# Get actual computer name
$actualHostname = $env:COMPUTERNAME
$normalizedHostname = $actualHostname.Trim().ToUpper()

Write-Host "=== Hostname Diagnostic ===" -ForegroundColor Cyan
Write-Host "Actual COMPUTERNAME: '$actualHostname'" -ForegroundColor Yellow
Write-Host "Normalized (UPPERCASE): '$normalizedHostname'" -ForegroundColor Yellow
Write-Host ""

# Get all devices from database
Write-Host "=== All Devices in Database ===" -ForegroundColor Cyan
try {
    $devicesUrl = "$SupabaseUrl/rest/v1/devices?select=hostname&limit=100"
    $allDevices = Invoke-RestMethod -Uri $devicesUrl -Method GET -Headers $headers
    foreach ($device in $allDevices) {
        $dbHostname = $device.hostname
        $dbNormalized = $dbHostname.Trim().ToUpper()
        $match = ($dbNormalized -eq $normalizedHostname)
        $matchStatus = if ($match) { "✓ MATCH" } else { "✗" }
        Write-Host "  $matchStatus DB: '$dbHostname' (normalized: '$dbNormalized')" -ForegroundColor $(if ($match) { 'Green' } else { 'Gray' })
    }
} catch {
    Write-Host "Error fetching devices: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== All Pending Commands ===" -ForegroundColor Cyan
try {
    $commandsUrl = "$SupabaseUrl/rest/v1/device_commands?status=eq.pending&select=id,device_hostname,command_type,created_at&order=created_at.desc&limit=20"
    $allCommands = Invoke-RestMethod -Uri $commandsUrl -Method GET -Headers $headers
    if ($allCommands -and $allCommands.Count -gt 0) {
        foreach ($cmd in $allCommands) {
            $cmdHostname = $cmd.device_hostname
            $cmdNormalized = $cmdHostname.Trim().ToUpper()
            $match = ($cmdNormalized -eq $normalizedHostname)
            $matchStatus = if ($match) { "✓ MATCH" } else { "✗" }
            Write-Host "  $matchStatus Command: $($cmd.command_type) | Hostname: '$cmdHostname' (normalized: '$cmdNormalized') | Created: $($cmd.created_at)" -ForegroundColor $(if ($match) { 'Green' } else { 'Gray' })
        }
    } else {
        Write-Host "  No pending commands found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error fetching commands: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Testing Exact Match Query ===" -ForegroundColor Cyan
try {
    $exactUrl = "$SupabaseUrl/rest/v1/device_commands?device_hostname=eq.$normalizedHostname&status=eq.pending&select=*"
    $exactMatch = Invoke-RestMethod -Uri $exactUrl -Method GET -Headers $headers
    Write-Host "  Found $($exactMatch.Count) command(s) with exact match" -ForegroundColor $(if ($exactMatch.Count -gt 0) { 'Green' } else { 'Yellow' })
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Recommendation ===" -ForegroundColor Cyan
Write-Host "If hostnames don't match, ensure device hostname in database matches normalized hostname: '$normalizedHostname'" -ForegroundColor Yellow
Write-Host "You can update device hostname in Supabase or ensure enrollment uses the correct hostname." -ForegroundColor Yellow

