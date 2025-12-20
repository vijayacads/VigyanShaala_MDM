# Option 1 Implementation Steps

## ✅ Migration 025: Remove Anon SELECT Policies

This migration will:
- ✅ Block device enumeration (security)
- ✅ Keep all production features working
- ❌ Break verification script (non-production)

## Step 1: Run Migration 025

1. Open Supabase Dashboard
2. Go to **SQL Editor**
3. Open file: `supabase/migrations/025_fix_remove_anon_select_policies.sql`
4. Copy entire contents
5. Paste into SQL Editor
6. Click **Run** (or Ctrl+Enter)
7. Verify success: Should see "Success. No rows returned"

## Step 2: Verify Policies

Run this query to confirm anon SELECT policies are removed:

```sql
-- Check devices policies
SELECT policyname, roles, cmd 
FROM pg_policies 
WHERE tablename = 'devices' 
ORDER BY policyname;

-- Check device_health policies  
SELECT policyname, roles, cmd 
FROM pg_policies 
WHERE tablename = 'device_health' 
ORDER BY policyname;
```

**Expected Result:**
- ✅ `Authenticated users can read devices` (SELECT, authenticated only)
- ✅ `Authenticated users can read device health` (SELECT, authenticated only)
- ❌ NO anon SELECT policies should exist

## Step 3: Test Enumeration is Blocked

Run the test script:
```powershell
cd osquery-agent
.\test-rls-restrictions-ready.ps1
```

**Expected Results:**
- Test 1: [FAILED] - Device read blocked (expected)
- Test 2: [FAILED] - Health read blocked (expected)
- Test 3: [SUCCESS] - Enumeration blocked ✅
- Test 4: [SUCCESS] - Enumeration blocked ✅

## Step 4: Verify Production Features

### Dashboard
1. Log into dashboard
2. Check Device Inventory - should see all devices ✅
3. Check Device Map - should see all devices ✅
4. Check Device Control - should see all devices ✅

### Enrollment
1. Run enrollment script on a test device
2. Device should be created ✅
3. Check dashboard - device should appear ✅

### Uninstaller
1. Run uninstaller script
2. Device should be deleted ✅

### Scheduled Tasks
Wait 5-10 minutes and verify:
- Health data still being collected ✅
- Commands still being processed ✅
- Chat/notifications still work ✅

## ✅ Implementation Complete

After migration 025:
- ✅ Security: Enumeration blocked
- ✅ Production: All features work
- ❌ Verification script: Broken (acceptable)




