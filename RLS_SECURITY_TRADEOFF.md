# RLS Security Trade-off

## Current Situation

After running migration 024, anon users **cannot** read devices or device_health tables directly. This blocks enumeration but breaks the verification script.

## What Works

✅ **Dashboard** - Uses authenticated session, can read all devices  
✅ **Enrollment** - INSERT still works (anon can insert)  
✅ **Uninstaller** - DELETE still works (anon can delete by hostname)  
✅ **Scheduled Tasks** - Don't need to read devices table  
✅ **Edge Function** - Uses service role, can read/write everything  

## What Breaks

❌ **Verification Script** (`verify-supabase-data.ps1`) - Can't read devices/health (anon blocked)  
❌ **Test Scripts** - Can't enumerate devices (this is good for security)

## Solution Options

### Option 1: Accept the Trade-off (Recommended)
- Remove verification script requirement
- Devices can verify via dashboard (authenticated)
- Better security (no enumeration possible)

### Option 2: Create Edge Function for Verification
- Create a new edge function: `verify-device`
- Takes hostname as parameter
- Uses service role to read device/health
- Returns device info
- Devices call this function instead of direct SELECT

### Option 3: Allow Anon SELECT (Less Secure)
- Keep anon SELECT policy
- Accept that enumeration is possible
- Devices can verify directly

## Recommendation

**Use Option 1** - The verification script is a nice-to-have, but security is more important. Devices can verify their enrollment by:
1. Checking dashboard (if they have access)
2. Trying to enroll again (will fail if already enrolled)
3. Checking if scheduled tasks are running (indicates successful enrollment)




