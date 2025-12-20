# Update Render Environment Variables

## ⚠️ CRITICAL: Commands Not Working?

If commands aren't appearing in the `device_commands` table, the dashboard is likely still using **OLD Supabase credentials**.

## Quick Fix

### Step 1: Go to Render Dashboard
1. Open https://dashboard.render.com
2. Click on your service: `vigyanshaala-mdm-dashboard`
3. Click **"Environment"** tab

### Step 2: Update These Variables

**Delete old values and add these NEW values:**

| Variable Name | New Value |
|--------------|-----------|
| `VITE_SUPABASE_URL` | `https://thqinhphunrflwlshdmx.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM` |

### Step 3: Save
- Click **"Save Changes"**
- Render will automatically redeploy
- Wait 2-3 minutes for deployment to complete

### Step 4: Verify
1. Go to your production dashboard URL
2. Try sending a command (lock/buzz/clear_cache)
3. Check Supabase: `device_commands` table should show the new command

## How to Verify Current Values

In Render Dashboard → Environment tab, you should see:
- **OLD URL:** `https://ujmcjezpmyvpiasfrwhm.supabase.co` ❌
- **NEW URL:** `https://thqinhphunrflwlshdmx.supabase.co` ✅

If you see the OLD URL, that's the problem!

## Why This Happens

The dashboard reads Supabase credentials from **environment variables** at build time:
- `dashboard/supabase.config.ts` uses `import.meta.env.VITE_SUPABASE_URL`
- These values come from Render's environment variables
- If not updated, dashboard connects to OLD project
- Commands go to OLD `device_commands` table
- But devices listen to NEW project → **mismatch!**

## After Update

✅ Dashboard connects to NEW Supabase project  
✅ Commands go to NEW `device_commands` table  
✅ Devices receive commands via Realtime  
✅ Everything works!


