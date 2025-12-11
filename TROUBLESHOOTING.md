# Troubleshooting Device Registration

## Device Not Appearing in Supabase Dashboard

If the installer completed without errors but the device doesn't show in Supabase:

### Step 1: Run Diagnostic Script

Run the diagnostic tool to check what's happening:

```powershell
cd osquery-agent
.\test-device-registration.ps1
```

Or manually test:

```powershell
.\enroll-device-debug.ps1
```

### Step 2: Check Required Migrations

Make sure these migrations have been run in Supabase SQL Editor:

1. **Migration 006** - Allows anonymous device registration
   ```sql
   -- File: supabase/migrations/006_allow_anonymous_device_registration.sql
   ```

2. **Migration 008** - Removes device ID (if you ran this)
   ```sql
   -- File: supabase/migrations/008_remove_device_id.sql
   ```

### Step 3: Check RLS Policies

The device might be inserted but not visible due to RLS (Row Level Security).

**Check in Supabase SQL Editor:**

```sql
-- Check if device exists (bypasses RLS)
SELECT * FROM devices WHERE hostname = 'YOUR_COMPUTER_NAME';
```

**If device exists but not visible in dashboard:**

RLS might be blocking SELECT queries. Temporarily check:

```sql
-- Temporarily disable RLS for testing (NOT for production)
ALTER TABLE devices DISABLE ROW LEVEL SECURITY;
```

Then check dashboard again. If it appears, the issue is RLS policies.

**Fix RLS for anonymous SELECT:**

```sql
-- Allow anonymous users to read devices (for dashboard)
CREATE POLICY "Allow anonymous read devices"
    ON devices FOR SELECT
    TO anon, authenticated
    USING (true);
```

### Step 4: Check PowerShell Output

Look at the PowerShell window where you ran the installer:

- Did it show "Device registered successfully!"?
- Any error messages in red?
- What hostname was registered?

### Step 5: Check Supabase Logs

1. Go to Supabase Dashboard → Logs → API Logs
2. Look for POST requests to `/rest/v1/devices`
3. Check for error responses (4xx, 5xx)

### Step 6: Verify Table Structure

If you ran migration 008 (removed ID column), verify the table structure:

```sql
-- Check devices table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'devices'
ORDER BY ordinal_position;
```

Expected columns:
- `hostname` (should be PRIMARY KEY)
- `device_inventory_code`
- `serial_number`
- `host_location`
- `city_town_village`
- `laptop_model`
- `latitude`
- `longitude`
- `os_version`
- NO `id` column (if migration 008 was run)

### Common Issues

**Issue 1: RLS blocking inserts**
- **Fix:** Run migration 006

**Issue 2: Table structure mismatch**
- **Fix:** Run migration 008 if you removed ID column

**Issue 3: Duplicate hostname**
- **Fix:** Use different hostname or delete existing device

**Issue 4: Invalid coordinates**
- **Fix:** Ensure latitude (-90 to 90) and longitude (-180 to 180) are valid

**Issue 5: Missing required fields**
- **Fix:** Ensure hostname, device_inventory_code, and host_location are provided

## Quick Test

Run this in Supabase SQL Editor to manually insert a test device:

```sql
INSERT INTO devices (
    hostname,
    device_inventory_code,
    host_location,
    latitude,
    longitude,
    compliance_status
) VALUES (
    'TEST-DEVICE',
    'TEST-001',
    'Test Location',
    18.5204,
    73.8567,
    'unknown'
);

-- Check if it appears
SELECT * FROM devices WHERE hostname = 'TEST-DEVICE';
```

If this works, the issue is with the installer script. If this fails, check table structure and RLS policies.

