# Installer Package - Ready for Testing

## What Was Created

✅ **Enhanced Enrollment Script** (`enroll-device.ps1`)
   - Full GUI form with all device fields
   - Auto-detects hostname, serial, OS version, laptop model
   - Validates coordinates
   - Registers device in Supabase

✅ **Master Installer** (`INSTALL.ps1`)
   - Installs osquery
   - Runs enrollment automatically
   - Handles errors gracefully

✅ **Package Generator** (`create-installer-package.ps1`)
   - Creates ready-to-distribute ZIP file
   - Pre-configures Supabase credentials

✅ **Quick Setup Script** (`QUICK-SETUP.ps1`)
   - Interactive script to create installer package
   - Asks for your Supabase credentials

✅ **RLS Migration** (`supabase/migrations/006_allow_anonymous_device_registration.sql`)
   - Allows device registration from installer scripts

## How to Create Installer Package

### Option 1: Quick Setup (Easiest)

```powershell
cd osquery-agent
.\QUICK-SETUP.ps1
```

Enter your Supabase URL and anon key when prompted.

### Option 2: Manual

```powershell
cd osquery-agent
.\create-installer-package.ps1 `
    -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
    -SupabaseKey "YOUR_ANON_KEY_HERE"
```

## Before Testing

### Step 1: Run RLS Migration

In Supabase SQL Editor, run:
```sql
-- File: supabase/migrations/006_allow_anonymous_device_registration.sql
```

This allows the installer to register devices without authentication.

### Step 2: Verify Locations Exist

Make sure you have locations in the database:
```sql
SELECT * FROM locations WHERE is_active = true;
```

The enrollment form needs locations for the dropdown.

## Testing on a Windows Machine

1. **Extract** `VigyanShaala-MDM-Installer.zip` to a folder
2. **Right-click** `RUN-AS-ADMIN.bat` → **"Run as Administrator"**
3. **Wait** for osquery to install (will auto-download if needed)
4. **Fill the enrollment form**:
   - Device Inventory Code: `TEST-001`
   - Device Name: (auto-filled, can edit)
   - Host Location: `Test Lab`
   - Latitude: `18.5204` (example for Pune)
   - Longitude: `73.8567` (example for Pune)
   - School Location: (select from dropdown)
5. **Click "Register Device"**
6. **Check dashboard** - device should appear

## What the Installer Does

1. ✅ Checks for Administrator privileges
2. ✅ Downloads osquery MSI if not present
3. ✅ Installs osquery silently
4. ✅ Copies configuration files
5. ✅ Installs osquery service
6. ✅ Shows enrollment form
7. ✅ Registers device in Supabase
8. ✅ Starts monitoring

## Device Registration Fields

The enrollment form collects:
- Device Inventory Code *
- Hostname * (auto-detected)
- Serial Number (auto-detected)
- Host Location (College, Lab, etc.) *
- City/Town/Village
- Laptop Model (auto-detected)
- OS Version (auto-detected)
- Latitude * (-90 to 90)
- Longitude * (-180 to 180)
- School Location * (from dropdown)

* = Required field

## Troubleshooting

### "Failed to load locations"
- Check internet connection
- Verify Supabase credentials in INSTALL.bat
- Run migration: `006_allow_anonymous_device_registration.sql`
- Verify locations exist: `SELECT * FROM locations WHERE is_active = true;`

### "Enrollment failed"
- Check internet connection
- Verify all required fields are filled
- Check coordinates are valid numbers
- Check Supabase API logs for errors

### "osquery installation failed"
- Ensure running as Administrator
- Check Windows Event Viewer for errors
- Try downloading osquery manually from https://osquery.io/downloads

### Device doesn't appear in dashboard
- Wait a few seconds and refresh
- Check Supabase dashboard → Table Editor → devices
- Verify RLS is allowing reads (might need to disable for testing)

## Files Created

```
osquery-agent/
├── enroll-device.ps1              # NEW: Enhanced enrollment form
├── INSTALL.ps1                    # NEW: Master installer
├── INSTALL.bat                    # NEW: Simple launcher
├── QUICK-SETUP.ps1                # NEW: Quick setup script
├── create-installer-package.ps1   # NEW: Package generator
├── README-TEACHER.md              # NEW: Instructions for teachers
├── SETUP-INSTRUCTIONS.md          # NEW: Admin setup guide
└── install-osquery.ps1            # UPDATED: Uses new enrollment script

supabase/migrations/
└── 006_allow_anonymous_device_registration.sql  # NEW: RLS migration
```

## Next Steps

1. ✅ Run RLS migration in Supabase
2. ✅ Create installer package using QUICK-SETUP.ps1
3. ✅ Test on a Windows machine
4. ✅ Verify device appears in dashboard
5. ✅ Distribute installer to teachers

## Distribution

Once tested, share `VigyanShaala-MDM-Installer.zip` with teachers. They just need to:
1. Extract ZIP
2. Run `RUN-AS-ADMIN.bat` as Administrator
3. Fill enrollment form
4. Done!

