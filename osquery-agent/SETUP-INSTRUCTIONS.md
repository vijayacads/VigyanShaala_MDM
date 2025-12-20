# Setup Instructions for Admin

## Step 1: Update RLS Policies

Before distributing the installer, run this SQL in Supabase SQL Editor:

```sql
-- Allow anonymous device registration for installer scripts
DROP POLICY IF EXISTS "Teachers can enroll devices" ON devices;

CREATE POLICY "Allow anonymous device enrollment"
    ON devices FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- Allow anonymous reads of locations (needed for dropdown)
DROP POLICY IF EXISTS "Locations are readable by authenticated users" ON locations;

CREATE POLICY "Locations are readable by all"
    ON locations FOR SELECT
    TO anon, authenticated
    USING (is_active = true);
```

Or run the migration file: `supabase/migrations/006_allow_anonymous_device_registration.sql`

## Step 2: Get Supabase Credentials

1. Go to Supabase Dashboard → Settings → API
2. Copy:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon public** key

## Step 3: Create Installer Package

Run the package creation script:

```powershell
cd osquery-agent
.\create-installer-package.ps1 `
    -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
    -SupabaseKey "YOUR_ANON_KEY_HERE"
```

This will create:
- `VigyanShaala-MDM-Installer.zip` - Ready to distribute to teachers

## Step 4: Distribute to Teachers

1. Share the ZIP file with teachers
2. Teachers extract and run `RUN-AS-ADMIN.bat`
3. The installer will:
   - Download osquery if needed
   - Install osquery
   - Show enrollment form
   - Register device in Supabase

## Testing

1. Test the installer on a Windows machine
2. Check that device appears in dashboard
3. Verify all fields are saved correctly

## Security Notes

- The anon key is safe for public use with RLS enabled
- Device registration is open, but device updates require admin role
- Consider adding rate limiting in production
- Consider using Supabase Edge Functions for additional validation




