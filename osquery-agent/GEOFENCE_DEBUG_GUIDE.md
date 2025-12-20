# Geofence Debug Guide

## Quick Start

### Option 1: PowerShell Script (Recommended)
Run the automated debug script:

```powershell
.\debug-geofence.ps1
```

The script will:
1. Check if device has `location_id` assigned
2. Verify location has `radius_meters` set
3. Check WiFi mappings for the location
4. Show existing geofence alerts
5. Test if `geofence-alert` function is deployed
6. Manually trigger a geofence check (if service role key provided)

**Note:** You'll be prompted for the Supabase Service Role Key. Get it from:
- Supabase Dashboard > Settings > API > `service_role` key (secret)

### Option 2: SQL Queries
Run queries in Supabase SQL Editor:

1. Open Supabase Dashboard > SQL Editor
2. Open `supabase/migrations/027_geofence_debug_queries.sql`
3. Replace `'YOUR_DEVICE_HOSTNAME'` with your device hostname
4. Run queries one by one

## Common Issues & Fixes

### Issue 1: Device has no location_id
**Check:**
```sql
SELECT hostname, location_id FROM devices WHERE hostname = 'YOUR_HOSTNAME';
```

**Fix:**
- Assign location in dashboard, OR
- Run SQL: `UPDATE devices SET location_id = 'UUID' WHERE hostname = 'YOUR_HOSTNAME';`

### Issue 2: Location has no radius_meters
**Check:**
```sql
SELECT id, name, radius_meters FROM locations WHERE id = 'YOUR_LOCATION_ID';
```

**Fix:**
```sql
UPDATE locations SET radius_meters = 1000 WHERE id = 'YOUR_LOCATION_ID';
```

### Issue 3: geofence-alert function not deployed
**Check:**
```bash
supabase functions list
```

**Fix:**
```bash
supabase functions deploy geofence-alert
```

### Issue 4: Geofence not triggering
**Important:** Geofence check ONLY triggers when:
- Device sends osquery data with GPS coordinates, OR
- Device sends WiFi data

It does NOT trigger when you manually update lat/long in the database.

**To manually test:**
```powershell
$SupabaseUrl = "https://ujmcjezpmyvpiasfrwhm.supabase.co"
$SupabaseKey = "YOUR_SERVICE_ROLE_KEY"  # Must be service role key
$deviceHostname = "YOUR_DEVICE_HOSTNAME"
$testLat = 28.7041  # Different location
$testLon = 77.1025

$body = @{
    device_id = $deviceHostname
    latitude = $testLat
    longitude = $testLon
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $SupabaseKey"
    "Content-Type" = "application/json"
}

Invoke-RestMethod -Uri "$SupabaseUrl/functions/v1/geofence-alert" -Method POST -Headers $headers -Body $body
```

## Debug Checklist

- [ ] Device exists in database
- [ ] Device has `location_id` assigned
- [ ] Location exists and is active
- [ ] Location has `radius_meters` > 0
- [ ] `geofence-alert` function is deployed
- [ ] Device is sending osquery data (GPS or WiFi)
- [ ] Check device `last_seen` timestamp (should be recent)
- [ ] Check for existing alerts in `geofence_alerts` table

## Understanding Geofence Behavior

### GPS-Based Geofencing
- Triggers when device sends GPS coordinates via osquery
- Calculates distance from device to location center
- Creates alert if distance > `radius_meters`

### WiFi-Based Geofencing
- Triggers when device sends WiFi SSID data
- Checks if WiFi SSID matches `location_wifi_mappings`
- Creates alert if WiFi SSID doesn't match location

### Alert Resolution
- Alerts are automatically resolved when device returns within geofence
- Manual resolution: Update `resolved_at` in `geofence_alerts` table




