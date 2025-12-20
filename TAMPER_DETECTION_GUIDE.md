# Tamper Detection & Bypass Monitoring Guide
## How to Track When Users Bypass MDM

**Date:** 2025-01-15  
**Purpose:** Detect when users bypass MDM so you can physically take away the laptop

---

## Executive Summary

**Current Capability:** ⚠️ **PARTIAL** - You can detect some bypass attempts, but not all.

**What You CAN Track:**
- ✅ Device goes offline (stops sending data)
- ✅ Tasks are stopped (if you check manually)
- ✅ Service is stopped (if you check manually)

**What You CANNOT Track (Currently):**
- ❌ Automatic alerts when bypass happens
- ❌ Real-time tamper detection
- ❌ Who stopped the tasks/service
- ❌ When exactly bypass occurred
- ❌ Network blocking attempts

**Solution:** Implement automated tamper detection system (see below)

---

## Current Tracking Capabilities

### 1. ✅ Device Heartbeat (`last_seen`)

**What It Tracks:**
- When device last sent data to server
- Updated every 5-25 minutes (depending on scheduled task)

**How to Check:**
```sql
-- In Supabase SQL Editor:
SELECT 
  hostname,
  last_seen,
  NOW() - last_seen as time_since_last_seen,
  CASE 
    WHEN NOW() - last_seen < INTERVAL '10 minutes' THEN 'Online'
    WHEN NOW() - last_seen < INTERVAL '30 minutes' THEN 'Warning'
    ELSE 'OFFLINE - POSSIBLE BYPASS'
  END as status
FROM devices
ORDER BY last_seen DESC;
```

**What It Detects:**
- ✅ Device stopped sending data (network blocked, tasks stopped, service stopped)
- ✅ Device uninstalled MDM
- ✅ Device powered off

**Limitations:**
- ⚠️ Cannot tell WHY device is offline (network issue vs bypass)
- ⚠️ No automatic alert
- ⚠️ Must check manually

---

### 2. ✅ Scheduled Task Status (Manual Check)

**What It Tracks:**
- Status of MDM scheduled tasks
- Last run time
- Task state (Running/Ready/Disabled)

**How to Check (On Device):**
```powershell
# Check all MDM tasks:
Get-ScheduledTask -TaskName "VigyanShaala-MDM-*" | 
  Select-Object TaskName, State, @{N='LastRun';E={(Get-ScheduledTaskInfo $_.TaskName).LastRunTime}}
```

**What It Detects:**
- ✅ Tasks stopped by user
- ✅ Tasks disabled by user
- ✅ Tasks deleted

**Limitations:**
- ⚠️ Must run ON THE DEVICE (requires physical access)
- ⚠️ No remote monitoring
- ⚠️ No automatic alert

---

### 3. ✅ Service Status (Manual Check)

**What It Tracks:**
- osquery service status
- Service start/stop events

**How to Check (On Device):**
```powershell
# Check osquery service:
Get-Service osqueryd | Select-Object Name, Status, StartType
```

**What It Detects:**
- ✅ Service stopped
- ✅ Service disabled

**Limitations:**
- ⚠️ Must run ON THE DEVICE
- ⚠️ No remote monitoring
- ⚠️ No automatic alert

---

## What You CANNOT Track (Currently)

### ❌ Real-Time Tamper Detection
- No automatic monitoring
- No alerts when tasks are stopped
- No alerts when service is stopped

### ❌ Who Bypassed MDM
- No logging of who stopped tasks
- No logging of who stopped service
- No user tracking

### ❌ When Bypass Occurred
- Can see device went offline, but not exact time
- No timestamp of when tasks were stopped

### ❌ Network Blocking
- Cannot detect if user blocked Supabase URL
- Device just appears offline

---

## Solution: Implement Automated Tamper Detection

### Option 1: Server-Side Monitoring (Recommended)

**How It Works:**
1. Monitor `last_seen` in database
2. Alert when device hasn't checked in for X minutes
3. Check for suspicious patterns

**Implementation:**

#### Step 1: Create Tamper Detection Table

```sql
-- Create table to track tamper events
CREATE TABLE IF NOT EXISTS tamper_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_hostname TEXT NOT NULL REFERENCES devices(hostname),
  event_type TEXT NOT NULL, -- 'offline', 'task_stopped', 'service_stopped', 'network_blocked'
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen_before TIMESTAMPTZ,
  details JSONB,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES auth.users(id),
  notes TEXT
);

CREATE INDEX idx_tamper_events_device ON tamper_events(device_hostname);
CREATE INDEX idx_tamper_events_unresolved ON tamper_events(resolved_at) WHERE resolved_at IS NULL;
CREATE INDEX idx_tamper_events_detected ON tamper_events(detected_at DESC);
```

#### Step 2: Create Monitoring Function

```sql
-- Function to detect offline devices (possible bypass)
CREATE OR REPLACE FUNCTION detect_offline_devices()
RETURNS TABLE (
  device_hostname TEXT,
  last_seen TIMESTAMPTZ,
  minutes_offline NUMERIC,
  severity TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.hostname,
    d.last_seen,
    EXTRACT(EPOCH FROM (NOW() - d.last_seen)) / 60 as minutes_offline,
    CASE
      WHEN NOW() - d.last_seen > INTERVAL '60 minutes' THEN 'critical'
      WHEN NOW() - d.last_seen > INTERVAL '30 minutes' THEN 'high'
      WHEN NOW() - d.last_seen > INTERVAL '15 minutes' THEN 'medium'
      ELSE 'low'
    END as severity
  FROM devices d
  WHERE d.last_seen < NOW() - INTERVAL '10 minutes'  -- Offline for more than 10 minutes
    AND d.last_seen IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM tamper_events te
      WHERE te.device_hostname = d.hostname
        AND te.event_type = 'offline'
        AND te.resolved_at IS NULL
        AND te.detected_at > NOW() - INTERVAL '1 hour'  -- Don't duplicate recent alerts
    )
  ORDER BY d.last_seen ASC;
END;
$$ LANGUAGE plpgsql;
```

#### Step 3: Create Scheduled Check (Supabase Edge Function)

Create a new Edge Function: `check-tamper-detection`

```typescript
// supabase/functions/check-tamper-detection/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Check for offline devices
    const { data: offlineDevices, error } = await supabaseClient
      .rpc('detect_offline_devices')

    if (error) throw error

    // Create tamper events for offline devices
    const tamperEvents = offlineDevices.map(device => ({
      device_hostname: device.device_hostname,
      event_type: 'offline',
      severity: device.severity,
      last_seen_before: device.last_seen,
      details: {
        minutes_offline: device.minutes_offline,
        detected_at: new Date().toISOString()
      }
    }))

    if (tamperEvents.length > 0) {
      const { error: insertError } = await supabaseClient
        .from('tamper_events')
        .insert(tamperEvents)

      if (insertError) throw insertError

      // TODO: Send email/SMS alert here
      console.log(`Alert: ${tamperEvents.length} devices possibly bypassed MDM`)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        devices_checked: offlineDevices.length,
        tamper_events_created: tamperEvents.length
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

#### Step 4: Schedule the Check

Use Supabase Cron or external scheduler (cron job, GitHub Actions, etc.) to call this function every 5-10 minutes:

```sql
-- If using pg_cron extension:
SELECT cron.schedule(
  'check-tamper-detection',
  '*/10 * * * *',  -- Every 10 minutes
  $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/check-tamper-detection',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    )
  );
  $$
);
```

---

### Option 2: Client-Side Health Reporting (More Detailed)

**How It Works:**
1. Device reports its own health status
2. Includes task status, service status
3. Server detects anomalies

**Implementation:**

#### Step 1: Create Health Report Script

```powershell
# osquery-agent/report-health.ps1
param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabaseKey = $env:SUPABASE_ANON_KEY,
    [string]$DeviceHostname = $env:COMPUTERNAME
)

$DeviceHostname = $DeviceHostname.Trim().ToUpper()

# Check scheduled tasks
$tasks = @(
    "VigyanShaala-MDM-RealtimeListener",
    "VigyanShaala-MDM-SendOsqueryData",
    "VigyanShaala-UserNotify-Agent"
)

$taskStatus = @{}
foreach ($taskName in $tasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskName $taskName
        $taskStatus[$taskName] = @{
            exists = $true
            state = $task.State.ToString()
            enabled = $task.State -ne "Disabled"
            last_run = $info.LastRunTime
            last_result = $info.LastTaskResult
        }
    } else {
        $taskStatus[$taskName] = @{
            exists = $false
            state = "NOT_FOUND"
            enabled = $false
        }
    }
}

# Check osquery service
$service = Get-Service -Name "osqueryd" -ErrorAction SilentlyContinue
$serviceStatus = @{
    exists = $null -ne $service
    running = $service.Status -eq "Running" -if $service
    start_type = $service.StartType.ToString() -if $service
}

# Check if files exist
$files = @{
    osquery_exe = Test-Path "C:\Program Files\osquery\osqueryd.exe"
    config_file = Test-Path "C:\Program Files\osquery\osquery.conf"
    realtime_script = Test-Path "C:\Program Files\osquery\realtime-command-listener.ps1"
}

# Build health report
$healthReport = @{
    device_hostname = $DeviceHostname
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    tasks = $taskStatus
    service = $serviceStatus
    files = $files
    tamper_detected = $false
    tamper_reasons = @()
}

# Detect tampering
if (-not $serviceStatus.exists -or -not $serviceStatus.running) {
    $healthReport.tamper_detected = $true
    $healthReport.tamper_reasons += "osquery service not running"
}

foreach ($taskName in $tasks) {
    if (-not $taskStatus[$taskName].exists) {
        $healthReport.tamper_detected = $true
        $healthReport.tamper_reasons += "Task $taskName not found"
    } elseif (-not $taskStatus[$taskName].enabled) {
        $healthReport.tamper_detected = $true
        $healthReport.tamper_reasons += "Task $taskName is disabled"
    }
}

# Send to Supabase
$headers = @{
    "apikey" = $SupabaseKey
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
}

$body = $healthReport | ConvertTo-Json -Depth 10

try {
    $url = "$SupabaseUrl/rest/v1/device_health_reports"
    Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body | Out-Null
    
    if ($healthReport.tamper_detected) {
        Write-Host "⚠️ TAMPER DETECTED: $($healthReport.tamper_reasons -join ', ')" -ForegroundColor Red
    } else {
        Write-Host "✓ Health report sent successfully" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to send health report: $_"
}
```

#### Step 2: Create Health Reports Table

```sql
CREATE TABLE IF NOT EXISTS device_health_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_hostname TEXT NOT NULL REFERENCES devices(hostname),
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  tasks JSONB,
  service JSONB,
  files JSONB,
  tamper_detected BOOLEAN DEFAULT false,
  tamper_reasons TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_health_reports_device ON device_health_reports(device_hostname);
CREATE INDEX idx_health_reports_tamper ON device_health_reports(tamper_detected) WHERE tamper_detected = true;
CREATE INDEX idx_health_reports_timestamp ON device_health_reports(timestamp DESC);
```

#### Step 3: Schedule Health Reports

Add to `install-osquery.ps1`:

```powershell
# Create health reporting task (runs every 5 minutes)
$healthTaskName = "VigyanShaala-MDM-HealthReport"
$healthScript = "$InstallDir\report-health.ps1"
$healthTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$healthScript`""
$healthTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365)
$healthTaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$healthTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $healthTaskName -Action $healthTaskAction -Trigger $healthTaskTrigger -Principal $healthTaskPrincipal -Settings $healthTaskSettings -Description "Report device health and detect tampering every 5 minutes" -Force
```

---

## Dashboard Integration

### Add Tamper Detection View

Create a new dashboard component to show tamper events:

```typescript
// dashboard/src/components/TamperDetection.tsx
// Shows list of devices that may have bypassed MDM
// Shows tamper events with severity
// Allows marking as resolved
```

**Features:**
- List of offline devices (sorted by time offline)
- List of tamper events
- Filter by severity
- Mark events as resolved
- Export to CSV for reporting

---

## Alerting

### Email Alerts

When tamper is detected, send email:

```typescript
// In check-tamper-detection function:
if (tamperEvents.length > 0) {
  // Send email using Supabase Edge Function or external service
  await sendEmail({
    to: 'admin@vigyanshaala.org',
    subject: `MDM Tamper Alert: ${tamperEvents.length} Device(s)`,
    body: `
      The following devices may have bypassed MDM:
      ${tamperEvents.map(e => `- ${e.device_hostname} (${e.severity})`).join('\n')}
      
      Please investigate and physically collect these devices.
    `
  })
}
```

### SMS Alerts (Optional)

Use Twilio or similar service for SMS alerts on critical tamper events.

---

## How to Use This System

### Daily Workflow:

1. **Check Dashboard** - View tamper detection page
2. **Review Alerts** - See which devices are offline/tampered
3. **Investigate** - Check if it's a real bypass or just network issue
4. **Take Action** - Physically collect laptop if confirmed bypass
5. **Mark Resolved** - Update tamper event status

### Alert Thresholds:

- **Low (10-15 min offline):** Monitor, may be network issue
- **Medium (15-30 min offline):** Investigate, possible bypass
- **High (30-60 min offline):** Likely bypass, prepare to collect
- **Critical (60+ min offline):** Definite bypass, collect immediately

---

## Testing Tamper Detection

### Test 1: Stop Scheduled Task
```powershell
# On device, stop a task:
Stop-ScheduledTask -TaskName "VigyanShaala-MDM-SendOsqueryData"
# Wait 10-15 minutes
# Check dashboard - should show device offline
```

### Test 2: Stop Service
```powershell
# On device, stop service:
Stop-Service osqueryd
# Wait 10-15 minutes
# Check dashboard - should show device offline
```

### Test 3: Block Network
```powershell
# On device, block Supabase URL:
New-NetFirewallRule -DisplayName "Block MDM" -Direction Outbound -RemoteAddress "your-project.supabase.co" -Action Block
# Wait 10-15 minutes
# Check dashboard - should show device offline
```

---

## Summary

**Current State:**
- ⚠️ Can detect offline devices manually
- ⚠️ No automatic alerts
- ⚠️ No tamper event tracking

**After Implementation:**
- ✅ Automatic detection every 5-10 minutes
- ✅ Email/SMS alerts on tamper
- ✅ Dashboard view of tamper events
- ✅ Historical tracking
- ✅ Can identify which devices to collect

**Action Required:**
1. Implement tamper detection system (Option 1 or 2)
2. Set up alerting
3. Add dashboard view
4. Test with real devices

---

## Questions?

If you need help implementing this, I can:
1. Create the tamper detection tables and functions
2. Create the health reporting script
3. Set up the monitoring Edge Function
4. Add dashboard components
5. Configure alerting

Let me know which parts you'd like me to implement first.
