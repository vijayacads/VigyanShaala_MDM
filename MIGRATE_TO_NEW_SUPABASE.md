# Migrate to New Supabase Project

## Step 1: Install Supabase CLI

```powershell
# Install via npm (requires Node.js)
npm install -g supabase

# Or install via Scoop (Windows)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

## Step 2: Create New Supabase Project

1. Go to https://supabase.com/dashboard
2. Click "New Project"
3. Fill in:
   - **Name**: VigyanShaala-MDM (or your choice)
   - **Database Password**: (save this securely)
   - **Region**: Choose closest to you
   - **Pricing Plan**: Free tier
4. Wait for project to be created (~2 minutes)

## Step 3: Link Local Project to New Supabase Project

```powershell
# Navigate to project root
cd C:\Users\vijay\Documents\GitHub\VigyanShaala_MDM

# Login to Supabase CLI
supabase login

# Link to your new project (get project ref from dashboard URL)
# URL format: https://supabase.com/dashboard/project/XXXXX
# XXXXX is your project-ref
supabase link --project-ref YOUR_NEW_PROJECT_REF
```

## Step 4: Apply All Migrations

```powershell
# Push all migrations to new project
supabase db push

# Or apply migrations manually via SQL Editor (if CLI doesn't work)
```

## Step 5: Manual Migration (If CLI Fails)

If `supabase db push` doesn't work on free tier, run migrations manually:

1. Go to Supabase Dashboard → SQL Editor
2. Run migrations in this order:

### Critical Migrations (Run These First):

1. `001_locations.sql` - Creates locations table
2. `002_devices.sql` - Creates devices table (NOTE: This was modified - devices now uses hostname as PK, not id)
3. `003_software_web_activity.sql` - Software and web activity tables
4. `008_remove_device_id.sql` - Changes devices PK from id to hostname
5. `013_recreate_locations.sql` - Recreates locations with proper RLS
6. `014_restore_foreign_keys.sql` - Restores foreign key relationships
7. `015_add_device_metrics_and_health.sql` - Device health table
8. `017_create_device_commands.sql` - Device commands table
9. `018_create_chat_messages.sql` - Chat messages table
10. `022_create_user_notifications.sql` - User notifications table
11. `027_fix_device_enrollment_with_security_definer.sql` - Enrollment function
12. `028_enable_realtime_for_device_commands.sql` - Enable Realtime

### RLS Migrations (Run After Tables):

- `006_allow_anonymous_device_registration.sql`
- `009_allow_anonymous_read_devices.sql`
- `022_allow_anon_read_device_health.sql`
- `024_restrict_devices_with_device_access.sql`
- `025_fix_remove_anon_select_policies.sql`
- `026_verify_and_fix_rls.sql`

## Step 6: Get New Project Credentials

1. Go to **Settings** → **API**
2. Copy:
   - **Project URL**: `https://XXXXX.supabase.co`
   - **anon public key**: `eyJhbGci...`

## Step 7: Update Configuration Files

Update these files with new credentials:

1. **Dashboard**: `dashboard/.env`
   ```
   VITE_SUPABASE_URL=https://NEW_PROJECT_REF.supabase.co
   VITE_SUPABASE_ANON_KEY=NEW_ANON_KEY
   ```

2. **Installer scripts**: Update Supabase URL/Key in:
   - `osquery-agent/enroll-device.ps1`
   - `osquery-agent/install-osquery.ps1`
   - Any other scripts that use Supabase

## Step 8: Verify Setup

```sql
-- Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Should see:
-- device_commands
-- device_health
-- devices
-- locations
-- software_inventory
-- user_notifications
-- web_activity

-- Check Realtime is enabled
SELECT * FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename = 'device_commands';

-- Should return 1 row

-- Check enroll_device function exists
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'enroll_device';

-- Should return enroll_device
```

## Quick Migration Script

Create a PowerShell script to apply all migrations:

```powershell
# apply-all-migrations.ps1
$migrations = Get-ChildItem "supabase\migrations\*.sql" | Sort-Object Name

foreach ($migration in $migrations) {
    Write-Host "Applying: $($migration.Name)" -ForegroundColor Yellow
    # You'll need to manually copy SQL content to Supabase SQL Editor
    # Or use Supabase CLI if available
    Get-Content $migration.FullName
    Write-Host "---" -ForegroundColor Gray
}
```

## Important Notes

1. **Migration Order Matters**: Some migrations depend on previous ones
2. **RLS Policies**: Make sure RLS policies are correct for anonymous enrollment
3. **Realtime**: Must enable Realtime for `device_commands` table (migration 028)
4. **Functions**: `enroll_device` function must exist (migration 027)
5. **Primary Key**: Devices table uses `hostname` as PK (not `id`) after migration 008

## Troubleshooting

- **CLI not working**: Use SQL Editor manually
- **RLS errors**: Check migration 026 and 027
- **Realtime not working**: Verify migration 028 ran successfully
- **Enrollment fails**: Check `enroll_device` function exists and has correct permissions


