# Quick Setup Guide - 5 Devices with 6-Digit IDs

## Step 1: Clean Start (Optional)

If you want to start fresh, run this first:
```sql
-- Run: 000_drop_old_tables.sql
```

## Step 2: Run Migrations in Order

1. **Locations Table:**
   ```sql
   -- Run: 001_locations.sql
   -- Creates locations table and seeds 5 locations
   ```

2. **Devices Table:**
   ```sql
   -- Run: 002_devices.sql
   -- Creates devices table with INTEGER 6-digit IDs (100000-999999)
   -- Creates geofence_alerts table
   ```

3. **Software & Web Activity:**
   ```sql
   -- Run: 003_software_web_activity.sql
   -- Creates software_inventory, web_activity, and blocklist tables
   ```

4. **Seed Data:**
   ```sql
   -- Run: 004_seed_dummy_devices.sql
   -- Inserts 5 devices: 100001, 100002, 100003, 100004, 100005
   -- Each device gets 8 software entries and 10 web activities
   ```

## Step 3: Verify Data

```sql
-- Check devices
SELECT id, hostname, location_id, compliance_status 
FROM devices 
WHERE id BETWEEN 100001 AND 100005
ORDER BY id;

-- Check software count per device (should be 8 each)
SELECT device_id, COUNT(*) as software_count 
FROM software_inventory 
WHERE device_id BETWEEN 100001 AND 100005 
GROUP BY device_id
ORDER BY device_id;

-- Check web activity count per device (should be 10 each)
SELECT device_id, COUNT(*) as activity_count 
FROM web_activity 
WHERE device_id BETWEEN 100001 AND 100005 
GROUP BY device_id
ORDER BY device_id;

-- Total counts
SELECT 
    (SELECT COUNT(*) FROM devices WHERE id BETWEEN 100001 AND 100005) as devices,
    (SELECT COUNT(*) FROM software_inventory WHERE device_id BETWEEN 100001 AND 100005) as software,
    (SELECT COUNT(*) FROM web_activity WHERE device_id BETWEEN 100001 AND 100005) as web_activity;
```

## Expected Results

- **Devices:** 5 rows (IDs: 100001-100005)
- **Software Inventory:** 40 rows (8 per device)
- **Web Activity:** 50 rows (10 per device)
- **Locations:** 5 rows

## Device Details

| ID | Hostname | Location | Status | Software | Web Activity |
|----|----------|----------|--------|----------|--------------|
| 100001 | PC-LAB-001 | Pune School 1 | compliant | 8 | 10 |
| 100002 | PC-LAB-002 | Mumbai School 1 | compliant | 8 | 10 |
| 100003 | PC-LAB-003 | Delhi School 1 | non_compliant | 8 | 10 |
| 100004 | PC-LAB-004 | Bangalore School 1 | compliant | 8 | 10 |
| 100005 | PC-LAB-005 | Hyderabad School 1 | compliant | 8 | 10 |

## Notes

- Device IDs are now INTEGER (6 digits: 100000-999999)
- All foreign keys reference device.id as INTEGER
- Sequence starts at 100001 and auto-increments
- All 5 devices have consistent data across all tables
