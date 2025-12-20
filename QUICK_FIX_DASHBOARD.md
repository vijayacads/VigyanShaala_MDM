# Quick Fix for Dashboard "No Rows" Issue

## Problem
- Dashboard shows "Demo Mode" and "no rows to show"
- RLS (Row Level Security) is blocking unauthenticated requests
- Dashboard isn't logging in as admin user

## Quick Fix (2 options):

### Option 1: Disable RLS (Fastest - For Testing)

Run in Supabase SQL Editor:

```sql
ALTER TABLE devices DISABLE ROW LEVEL SECURITY;
ALTER TABLE locations DISABLE ROW LEVEL SECURITY;
ALTER TABLE software_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE web_activity DISABLE ROW LEVEL SECURITY;
ALTER TABLE geofence_alerts DISABLE ROW LEVEL SECURITY;
ALTER TABLE website_blocklist DISABLE ROW LEVEL SECURITY;
ALTER TABLE software_blocklist DISABLE ROW LEVEL SECURITY;
```

**Then refresh dashboard - data should appear immediately.**

---

### Option 2: Verify Data Exists First

Before disabling RLS, check if data is actually there:

```sql
-- Check devices
SELECT COUNT(*) FROM devices;  -- Should be 5

-- Check locations
SELECT COUNT(*) FROM locations;  -- Should be 5

-- Check if RLS is blocking
SELECT * FROM devices;  -- Run while logged in as admin user in Supabase
```

---

### Option 3: Add Anonymous Read Policies (Keep RLS)

If you want to keep RLS enabled but allow dashboard reads:

```sql
-- Drop existing policies first
DROP POLICY IF EXISTS "Teachers see devices in their location" ON devices;
DROP POLICY IF EXISTS "Locations are readable by authenticated users" ON locations;

-- Create new policies that allow anonymous reads
CREATE POLICY "Allow public read devices"
    ON devices FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Allow public read locations"
    ON locations FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Allow public read software"
    ON software_inventory FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Allow public read web activity"
    ON web_activity FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Allow public read alerts"
    ON geofence_alerts FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Allow public read blocklists"
    ON website_blocklist FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Allow public read software blocklist"
    ON software_blocklist FOR SELECT
    TO anon, authenticated
    USING (true);
```

---

## Verify Fix

After running Option 1 (disabling RLS):

1. Refresh dashboard
2. Should see 5 devices (100001-100005)
3. Map should show device locations
4. Inventory table should list devices

If still empty, check:
- Environment variables are correct in Render
- Tables have data (run SELECT queries above)
- No console errors in browser



