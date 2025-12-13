# Create New Installer Package

## Quick Steps to Create Updated Installer

Since you've completed migrations and edge functions, you now need to create a fresh installer package with all the new components.

### Step 1: Create the Installer Package

Run this PowerShell script **from the `osquery-agent` directory**:

```powershell
cd osquery-agent
.\create-installer-package.ps1 -SupabaseUrl "YOUR_SUPABASE_URL" -SupabaseAnonKey "YOUR_SUPABASE_KEY"
```

Replace:
- `YOUR_SUPABASE_URL`: Your Supabase project URL (e.g., `https://xxxxx.supabase.co`)
- `YOUR_SUPABASE_KEY`: Your Supabase anon key

This will create: `VigyanShaala-MDM-Installer.zip`

### Step 2: Copy to Dashboard Downloads

1. **Copy the ZIP file** to:
   ```
   dashboard/public/downloads/VigyanShaala-MDM-Installer.zip
   ```

2. **Also copy to dist folder** (if you've built the dashboard):
   ```
   dashboard/dist/downloads/VigyanShaala-MDM-Installer.zip
   ```

### Step 3: Verify Package Contents

The package should include:
- ✅ `INSTALL.bat` (pre-configured with your Supabase credentials)
- ✅ `RUN-AS-ADMIN.bat` (launcher)
- ✅ `INSTALL.ps1` (master installer)
- ✅ `uninstall-osquery.ps1` (uninstaller)
- ✅ `osquery-agent/` folder containing:
  - `install-osquery.ps1`
  - `enroll-device.ps1`
  - `osquery.conf` (with health queries)
  - `apply-website-blocklist.ps1`
  - `apply-software-blocklist.ps1`
  - `sync-blocklist-scheduled.ps1`
  - `sync-software-blocklist-scheduled.ps1`
  - `execute-commands.ps1` ← **NEW**
  - `chat-interface.ps1` ← **NEW**

### Step 4: Test the Package

1. **Extract on a test device**
2. **Run `RUN-AS-ADMIN.bat`**
3. **Verify installation completes**
4. **Check all scheduled tasks are created**
5. **Verify new files are in place**

---

## What's Included in the New Package

### New Components:
1. **execute-commands.ps1** - Processes device commands and broadcast messages
2. **chat-interface.ps1** - Chat UI for devices
3. **Updated osquery.conf** - Includes health tracking queries

### New Scheduled Task:
- **VigyanShaala-MDM-CommandProcessor** - Runs every 30 seconds to process commands

### Updated Installation:
- Automatically sets up command processor
- Copies chat interface script
- Sets up all environment variables
- Creates all scheduled tasks

---

## Distribution

Once the package is created and copied to the dashboard:

1. **Teachers/Admins** can download from:
   - Dashboard → Device Software Downloads tab
   - Direct link: `/downloads/VigyanShaala-MDM-Installer.zip`

2. **For existing devices**:
   - Follow `REINSTALLATION_GUIDE.md` to uninstall and reinstall

3. **For new devices**:
   - Download and run `RUN-AS-ADMIN.bat`

---

## Notes

- The installer package is pre-configured with your Supabase credentials
- No manual configuration needed during installation
- All new features are automatically set up
- Enrollment wizard will launch after installation

