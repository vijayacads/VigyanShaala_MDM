# Security & Tamper Detection Guide
## VigyanShaala MDM Platform

**Date:** 2025-01-15  
**Status:** 🔴 **NOT PRODUCTION-READY** - Critical vulnerabilities identified

---

## Executive Summary

**Security Issues:**
- ⚠️ Any authenticated user can control any device (no authorization)
- ⚠️ Anonymous users may send commands (if FIX_DEVICE_COMMANDS_RLS.sql applied)
- ⚠️ Devices can manipulate command status
- ⚠️ Limited tracking of illegal activities

**Tamper Detection:**
- ⚠️ Can detect offline devices manually
- ❌ No automatic alerts
- ❌ No real-time monitoring

---

## Critical Vulnerabilities

### 1. ⚠️ **No Authorization Checks**

**Problem:** Any authenticated user can send commands to ANY device.

**Current Policy:**
```sql
-- Allows any authenticated user OR target_type = 'all' bypass
CREATE POLICY "Users can create commands for accessible devices"
  ON device_commands FOR INSERT
  TO authenticated
  WITH CHECK (
    (role check) OR (location check) OR (target_type = 'all')  -- ⚠️ BYPASS
  );
```

**Fix:**
```sql
-- Restrict to admins only, remove target_type = 'all' bypass
CREATE POLICY "Only admins can create device commands"
  ON device_commands FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE users.id = auth.uid()
      AND (users.raw_user_meta_data->>'role') = ANY (ARRAY['admin', 'location_admin'])
    )
  );
```

---

### 2. ⚠️ **Anonymous Command Injection** (If FIX Applied)

**Problem:** `FIX_DEVICE_COMMANDS_RLS.sql` allows anonymous INSERT.

**Fix:** Remove `anon` from INSERT policy, keep only `authenticated`.

---

### 3. ⚠️ **Unrestricted Device Updates**

**Problem:** Any device can update ANY command status.

**Fix:** Restrict UPDATE to match `device_hostname`.

---

## Can You Track Illegal Activities?

### ✅ What IS Tracked:
- Commands sent (what, when, which device)
- User ID (if authenticated)
- Device heartbeat (`last_seen`)

### ❌ What is NOT Tracked:
- IP addresses
- Failed authentication attempts
- Policy violations
- Suspicious patterns
- Who stopped tasks/service

**Conclusion:** Can see WHAT and WHO (if authenticated), but not WHERE (IP) or detect patterns.

---

## Can Users Bypass MDM?

### Regular Users (No Admin):
- ✅ Can stop user-level tasks (buzz/toast)
- ✅ Can block network (firewall)
- ⚠️ Cannot uninstall (if lockdown script run)
- ⚠️ Cannot stop SYSTEM tasks (if lockdown script run)

### Admin Users:
- ✅ **CAN BYPASS COMPLETELY** - Full system access

### Critical Gap:
- ❌ Lockdown script (`prevent-uninstall.ps1`) **NOT auto-run** during installation
- Most devices have no protection

---

## Tamper Detection

### Current Capability: ⚠️ **PARTIAL**

**What You CAN Detect:**
- Device goes offline (`last_seen` stops updating)
- Manual check: Task/service status (requires physical access)

**What You CANNOT Detect:**
- Automatic alerts
- Real-time monitoring
- Who stopped tasks/service
- Exact bypass time

### Quick Check (Manual):
```sql
-- Check offline devices in Supabase:
SELECT 
  hostname,
  last_seen,
  NOW() - last_seen as time_offline,
  CASE 
    WHEN NOW() - last_seen < INTERVAL '10 minutes' THEN 'Online'
    WHEN NOW() - last_seen < INTERVAL '30 minutes' THEN 'Warning'
    ELSE 'OFFLINE - POSSIBLE BYPASS'
  END as status
FROM devices
WHERE last_seen < NOW() - INTERVAL '15 minutes'
ORDER BY last_seen ASC;
```

---

## Automated Tamper Detection (Recommended)

### Option 1: Server-Side Monitoring

**Step 1: Create Tamper Events Table**
```sql
CREATE TABLE tamper_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_hostname TEXT NOT NULL REFERENCES devices(hostname),
  event_type TEXT NOT NULL, -- 'offline', 'task_stopped', 'service_stopped'
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen_before TIMESTAMPTZ,
  details JSONB,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES auth.users(id)
);

CREATE INDEX idx_tamper_events_unresolved ON tamper_events(resolved_at) WHERE resolved_at IS NULL;
```

**Step 2: Create Detection Function**
```sql
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
  WHERE d.last_seen < NOW() - INTERVAL '10 minutes'
    AND d.last_seen IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM tamper_events te
      WHERE te.device_hostname = d.hostname
        AND te.event_type = 'offline'
        AND te.resolved_at IS NULL
        AND te.detected_at > NOW() - INTERVAL '1 hour'
    )
  ORDER BY d.last_seen ASC;
END;
$$ LANGUAGE plpgsql;
```

**Step 3: Create Edge Function** (`check-tamper-detection`)
```typescript
// Calls detect_offline_devices() every 5-10 minutes
// Creates tamper_events for offline devices
// Sends email alerts
```

**Step 4: Schedule Check**
- Use Supabase Cron or external scheduler
- Run every 5-10 minutes
- Alert on critical/high severity

---

### Option 2: Client-Side Health Reporting

**Create:** `osquery-agent/report-health.ps1`
- Checks task status, service status, files
- Reports tamper if detected
- Runs every 5 minutes via scheduled task

**Table:** `device_health_reports`
- Stores health reports with tamper detection
- Includes task/service/file status

---

## Immediate Fixes Required

### Priority 1: CRITICAL
1. ✅ Fix authorization (remove `target_type = 'all'` bypass)
2. ✅ Remove anonymous INSERT access
3. ✅ Fix device UPDATE policy
4. ✅ Auto-run lockdown script during installation

### Priority 2: HIGH
5. ✅ Implement tamper detection (Option 1 or 2)
6. ✅ Add audit logging with IP tracking
7. ✅ Add input validation
8. ✅ Set up email alerts

---

## Alert Thresholds

- **Low (10-15 min offline):** Monitor, may be network issue
- **Medium (15-30 min offline):** Investigate, possible bypass
- **High (30-60 min offline):** Likely bypass, prepare to collect
- **Critical (60+ min offline):** Definite bypass, collect immediately

---

## Testing

### Test Security:
```bash
# As non-admin user, try to control device:
curl -X POST ".../device_commands" \
  -H "Authorization: Bearer USER_TOKEN" \
  -d '{"device_hostname":"TEST","command_type":"lock"}'
# Expected: 403 Forbidden (after fixes)
```

### Test Tamper Detection:
```powershell
# On device, stop task:
Stop-ScheduledTask -TaskName "VigyanShaala-MDM-SendOsqueryData"
# Wait 15 minutes
# Check dashboard - should show device offline/tamper event
```

---

## Summary

**Security Status:** 🔴 **NOT SAFE**
- Authentication: ✅ Working
- Authorization: ❌ Missing/Broken
- Tracking: ⚠️ Limited

**Tamper Detection:** ⚠️ **PARTIAL**
- Manual: ✅ Can check offline devices
- Automatic: ❌ Not implemented
- Alerts: ❌ Not configured

**Action Required:**
1. Fix authorization immediately
2. Implement tamper detection
3. Set up alerts
4. Auto-run lockdown script

---

## Implementation Help

I can implement:
1. Secure RLS policies
2. Tamper detection tables/functions
3. Health reporting script
4. Monitoring Edge Function
5. Dashboard components
6. Alert system

Let me know which to implement first.
