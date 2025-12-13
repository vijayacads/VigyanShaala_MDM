# MDM Dashboard Enhancement - Implementation Complete

## ✅ What Has Been Completed

All features from the enhancement plan have been implemented:

1. ✅ **Logo Display Fix** - Header layout and centering fixed
2. ✅ **Parameter Centralization** - `shared/device-parameters.json` created
3. ✅ **Database Migrations** - All migrations created (015, 017, 018)
4. ✅ **Auto-fill Form** - AddDevice component updated with auto-fill
5. ✅ **Device Health Tracking** - osquery queries and edge function processing
6. ✅ **Excel Export** - Already implemented
7. ✅ **WiFi Geofence** - Already implemented
8. ✅ **Device Control** - Dashboard component and database table
9. ✅ **Chat Support** - Dashboard component and database table
10. ✅ **Agent Scripts** - PowerShell scripts for Windows devices

---

## 📋 Steps to Complete the Process

### Step 1: Run Database Migrations

Run these migrations in your Supabase SQL Editor **in order**:

1. **Migration 015**: `supabase/migrations/015_add_device_metrics_and_health.sql`
   - Adds new device columns (device_imei_number, device_make, role, issue_date, wifi_ssid)
   - Creates `device_health` table
   - Creates performance_status calculation function

2. **Migration 017**: `supabase/migrations/017_create_device_commands.sql`
   - Creates `device_commands` table for remote control and messaging

3. **Migration 018**: `supabase/migrations/018_create_chat_messages.sql`
   - Creates `chat_messages` table for live chat
   - Sets up automatic cleanup trigger (10 days)

**How to run:**
- Go to Supabase Dashboard → SQL Editor
- Copy and paste each migration file content
- Run each migration one at a time
- Verify no errors

---

### Step 2: Enable Realtime for Chat Messages

1. Go to Supabase Dashboard → Database → Replication
2. Find `chat_messages` table
3. Enable replication (toggle ON)
4. OR run this SQL:
   ```sql
   ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
   ```

---

### Step 3: Deploy Edge Functions

**The `fetch-osquery-data` function needs to be deployed to Supabase.**

#### Option A: Deploy via Supabase CLI (Recommended)

1. **Install Supabase CLI** (if not already installed):
   ```bash
   npm install -g supabase
   ```

2. **Login to Supabase**:
   ```bash
   supabase login
   ```

3. **Link your project**:
   ```bash
   supabase link --project-ref your-project-ref
   ```
   (Find your project ref in Supabase Dashboard → Settings → General → Reference ID)

4. **Deploy the function**:
   ```bash
   supabase functions deploy fetch-osquery-data
   ```

#### Option B: Deploy via Supabase Dashboard

1. Go to Supabase Dashboard → Edge Functions
2. Click "Create a new function"
3. Name it: `fetch-osquery-data`
4. Copy the code from: `supabase/functions/fetch-osquery-data/index.ts`
5. Paste into the editor
6. Click "Deploy"

#### Also Deploy Other Edge Functions:

```bash
supabase functions deploy geofence-alert
supabase functions deploy blocklist-sync
```

**Note:** If you see errors about missing functions, deploy all three:
- `geofence-alert` - Checks device location against geofences
- `fetch-osquery-data` - Receives and processes osquery data from devices
- `blocklist-sync` - Syncs blocklist rules to devices

---

### Step 4: Update osquery Configuration

The `osquery.conf` file has been updated with health tracking queries. 

**For existing devices:**
1. Copy the updated `osquery-agent/osquery.conf` to each device
2. Replace: `C:\ProgramData\osquery\osquery.conf`
3. Restart osquery service:
   ```powershell
   Restart-Service osqueryd
   ```

**For new installations:**
- The updated config is already in the installer package

---

### Step 5: Set Up Agent Scripts on Devices

#### A. Command/Message Polling Script

1. Copy `osquery-agent/execute-commands.ps1` to each device
2. Create a scheduled task to run it every 30-60 seconds:

```powershell
# Run as Administrator
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\ProgramData\osquery\execute-commands.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Seconds 30) -RepetitionDuration (New-TimeSpan -Days 365)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "MDM-CommandProcessor" -Action $action -Trigger $trigger -Principal $principal -Description "Processes MDM commands and messages"
```

3. Set environment variables (or modify script):
   ```powershell
   [System.Environment]::SetEnvironmentVariable("SUPABASE_URL", "your-url", "Machine")
   [System.Environment]::SetEnvironmentVariable("SUPABASE_ANON_KEY", "your-key", "Machine")
   ```

#### B. Chat Interface (Optional)

1. Copy `osquery-agent/chat-interface.ps1` to each device
2. Create a shortcut or scheduled task to launch it when needed
3. Users can run it manually for chat support

---

### Step 6: Test the Features

#### Test Device Health Tracking:
1. Wait 10-15 minutes after updating osquery config
2. Check `device_health` table in Supabase
3. Verify health metrics are being collected
4. Check dashboard - health status should appear

#### Test Device Control:
1. Go to Dashboard → Device Control tab
2. Select a device
3. Click "Lock Device" or "Clear Cache"
4. Check `device_commands` table - should show pending status
5. Wait 30-60 seconds - agent should process and update status

#### Test Broadcast Messages:
1. Go to Device Control tab
2. Select "All Devices" or a location
3. Enter a message and send
4. Check devices - should receive notification

#### Test Chat Support:
1. Go to Dashboard → Live Chat tab
2. Select a device
3. Send a message
4. On device, run `chat-interface.ps1`
5. Verify messages appear in real-time

---

### Step 7: Update Enrollment Scripts (Optional)

Update enrollment scripts to use new parameters:

1. **Windows**: `osquery-agent/enroll-device.ps1`
   - Update to collect `device_imei_number` instead of `serial_number`
   - Add `device_make` collection
   - Add `wifi_ssid` collection

2. **Android**: `android-agent/android-app/app/src/main/java/com/vigyanshaala/mdm/EnrollmentActivity.java`
   - Update to use new parameter names

---

### Step 8: Verify Dashboard Components

1. **Logo**: Check header - logo and title should be properly aligned
2. **Add Device Form**: 
   - Test auto-fill button
   - Verify new fields (IMEI, device_make, role, issue_date, wifi_ssid)
   - Verify old fields removed (serial_number, laptop_model)
3. **Device Inventory**: 
   - Check Excel export includes new columns
   - Verify health status column appears
4. **Device Control**: 
   - Test all buttons
   - Verify command history displays
5. **Chat Support**: 
   - Test real-time messaging
   - Verify device selection works

---

## 🔧 Configuration Notes

### Environment Variables for Agents

Set these on each device (or in scripts):
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anon key
- `COMPUTERNAME`: Auto-detected (Windows hostname)

### RLS Policies

All tables have RLS enabled. Ensure:
- Teachers can access their location's devices
- Admins can access all devices
- Anonymous users can insert health data and commands (for agents)

---

## 📝 Important Notes

1. **Performance Status**: Automatically calculated by database trigger based on:
   - Storage usage (< 80% = good, 80-90% = warning, > 90% = critical)
   - Battery health (if available)
   - Crash count

2. **Chat Cleanup**: Messages older than 10 days are automatically deleted on every insert

3. **Command Polling**: Agents poll every 30 seconds by default (configurable in script)

4. **WiFi Geofence**: Uses WiFi SSID for location tracking (GPS not available on Windows)

5. **Health Tracking**: Data collected every 5-15 minutes depending on query

---

## 🐛 Troubleshooting

### Health data not appearing:
- Check osquery service is running
- Verify osquery.conf has health queries
- Check edge function logs
- Verify device is enrolled

### Commands not executing:
- Check `execute-commands.ps1` is running (scheduled task)
- Verify environment variables are set
- Check `device_commands` table for errors
- Verify device hostname matches

### Chat not working:
- Verify Realtime is enabled for `chat_messages` table
- Check RLS policies allow access
- Verify agent script has correct credentials

---

## ✅ Completion Checklist

- [ ] All migrations run successfully
- [ ] Realtime enabled for chat_messages
- [ ] Edge function deployed with health tracking
- [ ] osquery.conf updated on devices
- [ ] Agent scripts deployed and scheduled
- [ ] Environment variables set on devices
- [ ] Dashboard components tested
- [ ] Device control tested
- [ ] Chat support tested
- [ ] Health tracking verified

---

## 📚 Files Created/Modified

### New Files:
- `shared/device-parameters.json`
- `supabase/migrations/015_add_device_metrics_and_health.sql`
- `supabase/migrations/017_create_device_commands.sql`
- `supabase/migrations/018_create_chat_messages.sql`
- `dashboard/src/components/DeviceControl.tsx`
- `dashboard/src/components/DeviceControl.css`
- `dashboard/src/components/ChatSupport.tsx`
- `dashboard/src/components/ChatSupport.css`
- `osquery-agent/execute-commands.ps1`
- `osquery-agent/chat-interface.ps1`

### Modified Files:
- `dashboard/src/App.tsx` (already had new components)
- `dashboard/src/App.css` (logo fix)
- `dashboard/src/components/AddDevice.tsx` (new fields, auto-fill)
- `osquery-agent/osquery.conf` (health queries)
- `supabase/functions/fetch-osquery-data/index.ts` (health processing)

---

**All code is complete and ready for deployment!** 🎉

---

## 🔄 Reinstallation Process for Existing Devices

If you need to reinstall on existing devices to get the new features:

1. **Uninstall existing installation** (see `REINSTALLATION_GUIDE.md`)
2. **Download new installer** from dashboard
3. **Install fresh package** (includes all new components)
4. **Verify new features** are working

**See `REINSTALLATION_GUIDE.md` for detailed step-by-step instructions.**

