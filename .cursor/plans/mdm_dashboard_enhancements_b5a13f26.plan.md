---
name: MDM Dashboard Enhancements
overview: "Implement major features: Excel export, WiFi-based geofence tracking, parameter centralization with device health metrics and auto-fill, logo display fix, Android APK package, device control/messaging (lock/unlock/clear cache/buzz/broadcast), and live chat support. Centralize all device parameters in a single configuration file for consistency across dashboard, forms, and installers."
todos: []
---

# MDM Dashboard Enhancements Plan

## 1. Excel Download Button for Dashboard

**Location**: `dashboard/src/components/AppInventory.tsx`

- Add "Export to Excel" button in inventory header
- Use `xlsx` library (install via npm)
- Export all visible/filtered device data
- Include all columns: inventory_code, hostname, location, city, device_make, status, OS version, last_seen, device_imei_number, assigned_teacher, assigned_student_leader, latitude, longitude, performance_status
- File naming: `VigyanShaala-Devices-YYYY-MM-DD.xlsx`

**Files to modify**:

- `dashboard/src/components/AppInventory.tsx` - Add export button and function
- `dashboard/src/components/AppInventory.css` - Style export button
- `dashboard/package.json` - Add `xlsx` dependency

---

## 2. Fix Geofence Tracking (WiFi-Based Geolocation)

**Issue**: Windows devices don't have GPS, so osquery geolocation table returns empty. Need WiFi-based location tracking.

**Solution**: WiFi network-based geolocation

**Implementation**:

- Use WiFi access point (SSID) information to determine approximate location
- Query WiFi networks using osquery: `SELECT * FROM wifi_networks` or Windows netsh commands
- Match WiFi SSID to known location mappings stored in database
- Update device location based on strongest WiFi signal match
- Fallback: Use manual location assignment if WiFi not available

**Database Changes**:

- Add `wifi_ssid` column to `devices` table (TEXT, optional)
- Create `location_wifi_mappings` table (optional):
- `location_id` (UUID, FK to locations)
- `wifi_ssid` (TEXT)
- `signal_strength_threshold` (INTEGER)

**Files to modify**:

- `osquery-agent/osquery.conf` - Remove geolocation query, add WiFi network query
- `supabase/functions/fetch-osquery-data/index.ts` - Process WiFi data and match to locations
- `osquery-agent/enroll-device.ps1` - Collect WiFi SSID during enrollment

**Note**: `wifi_ssid` column will be added in migration 015 (Step 3) along with other device metrics

---

## 3. Centralize Device Parameters Configuration

**Goal**: Single source of truth for all device fields used across:

- Dashboard table (`AppInventory.tsx`)
- Add/Edit Device form (`AddDevice.tsx`)
- Windows installer enrollment (`enroll-device.ps1`)
- Android enrollment (`EnrollmentActivity.java`)
- Database schema (`002_devices.sql`)

**Current Parameters** (existing):

- hostname
- device_inventory_code
- host_location
- city_town_village
- os_version
- latitude
- longitude
- assigned_teacher
- assigned_student_leader
- compliance_status
- last_seen

**New Parameters to Add**:

- device_imei_number (TEXT) - replaces serial_number
- device_make (TEXT) - e.g., "Dell", "HP", "Lenovo"
- role (TEXT) - device role/purpose
- issue_date (DATE)
- wifi_ssid (TEXT) - for WiFi-based geolocation

**Health Parameters** (tracked automatically, NOT in form):

- battery_health_percent (INTEGER, 0-100)
- storage_used_percent (INTEGER, 0-100)
- boot_time_avg_seconds (INTEGER)
- crash_error_count (INTEGER)
- performance_status (TEXT) - 'good' | 'warning' | 'critical' (calculated automatically)

**Performance Status Formula**:

- **Good**: storage_used_percent < 80 AND (battery_health_percent > 20 OR battery_health_percent IS NULL) AND crash_error_count = 0
- **Warning**: (storage_used_percent >= 80 AND storage_used_percent < 90) OR (battery_health_percent >= 10 AND battery_health_percent <= 20) OR (crash_error_count >= 1 AND crash_error_count <= 5)
- **Critical**: storage_used_percent >= 90 OR battery_health_percent < 10 OR crash_error_count > 5

**Note**: `compliance_status` and `last_seen` already provide device status and last login information, so no separate fields needed.

**Implementation**:

1. Create `shared/device-parameters.ts` (TypeScript) or `shared/device-parameters.json` (JSON) with all field definitions
2. Create database migration to add new columns and device_health table
3. Update all forms and tables to use centralized config
4. Update Windows installer enrollment form
5. Update Android enrollment form
6. Update dashboard table columns
7. **Auto-fill Feature**: When user adds device details in form, automatically populate:

- `device_imei_number` - from device hardware (Windows: WMI query, Android: TelephonyManager)
- `device_make` - from system info (Windows: WMI Win32_ComputerSystem, Android: Build.MANUFACTURER)
- `os_version` - from system (already collected)
- `hostname` - from system (already collected)
- Other device-based constant parameters that can be detected automatically

8. **Health Parameters**: Tracked automatically via osquery/agent, NOT included in manual form entry

**Files to create**:

- `shared/device-parameters.json` - Central parameter definitions
- `supabase/migrations/015_add_device_metrics_and_health.sql` - Database migration (includes device_health table)

**Files to modify**:

- `dashboard/src/components/AppInventory.tsx` - Use centralized config, add health status column
- `dashboard/src/components/AddDevice.tsx` - Use centralized config, add auto-fill functionality
- `osquery-agent/enroll-device.ps1` - Use centralized config, auto-detect device parameters
- `android-agent/android-app/app/src/main/java/com/vigyanshaala/mdm/EnrollmentActivity.java` - Use centralized config, auto-detect device parameters
- `supabase/migrations/002_devices.sql` - Reference for schema
- `osquery-agent/osquery.conf` - Add health check queries
- `supabase/functions/fetch-osquery-data/index.ts` - Process health data and calculate performance_status
- `dashboard/src/components/DeviceHealth.tsx` - Display health metrics (if not exists)

---

## 4. Fix Logo Display

**Issue**: Logo and app title sizing/centering issue - title overlapping with image

**Current State**:

- Logo path: `/logo.png` in `App.tsx` (line 47)
- Expected location: `dashboard/public/logo.png`
- App title "VigyanShaala MDM Dashboard" overlapping with logo image

**Solution**:

- Fix CSS layout to properly center logo and title
- Adjust flexbox/grid layout in header
- Ensure proper spacing between logo and title
- Add responsive sizing for logo
- Verify logo file exists in `dashboard/public/`
- Add error handling for missing logo

**Files to modify**:

- `dashboard/src/App.tsx` - Fix header layout structure
- `dashboard/src/App.css` - Fix logo and title positioning, centering, and spacing
- Verify `dashboard/public/logo.png` exists

---

## 6. Android APK Package

**Current State**:

- Android app code exists in `android-agent/android-app/`
- Build instructions in `android-agent/BUILD_REQUIREMENTS.md`
- Package creation script: `android-agent/create-android-package.ps1`

**Tasks**:

- Build APK using Android Studio or Gradle
- Package APK in ZIP for download
- Update download button to serve Android package
- Ensure APK includes all latest features (enrollment, blocking, etc.)

**Files to check/modify**:

- `android-agent/android-app/` - Build configuration
- `android-agent/create-android-package.ps1` - Package script
- `dashboard/src/components/DeviceDownloads.tsx` - Download link
- `dashboard/public/downloads/` - APK location

---

## 6. Device Control and Messaging (Lock/Unlock, Clear Cache, Buzz, Broadcast Messages)

**Goal**: Remote device control capabilities and messaging - lock/unlock devices, clear cache, buzz devices, and send broadcast messages.

**Database Changes**:

- Create new table: `device_commands` (handles commands AND messages)
- Columns:
- `id` (UUID, PRIMARY KEY)
- `device_hostname` (TEXT, FK to devices.hostname)
- `command_type` (TEXT: 'lock'/'unlock'/'clear_cache'/'buzz'/'broadcast_message')
- `message` (TEXT, optional - for broadcast messages)
- `target_type` (TEXT: 'single'/'location'/'all', optional - for broadcast)
- `target_location_id` (UUID, FK to locations, optional - for broadcast)
- `duration` (INTEGER, optional - for buzz command in seconds)
- `status` (TEXT: 'pending'/'completed'/'failed'/'dismissed'/'expired')
- `created_at` (TIMESTAMPTZ)
- `executed_at` (TIMESTAMPTZ)
- `expires_at` (TIMESTAMPTZ, optional - for broadcast messages)
- `error_message` (TEXT)
- `created_by` (UUID, FK to auth.users, optional)

**Communication Pattern**:

- **Push Model**: Dashboard writes command/message to `device_commands` table
- **Pull Model**: Agents poll every 30-60 seconds for pending commands/messages
- Query for commands: `SELECT * FROM device_commands WHERE device_hostname = ? AND command_type IN ('lock','unlock','clear_cache','buzz') AND status = 'pending' ORDER BY created_at LIMIT 1`
- Query for messages: `SELECT * FROM device_commands WHERE (device_hostname = ? OR target_type = 'all' OR target_location_id = ?) AND command_type = 'broadcast_message' AND status = 'pending' AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY created_at`
- After execution, agent updates status to 'completed', 'failed', or 'dismissed' (for messages)

**Agent Implementation**:

- **Windows**:
- Lock: `rundll32.exe user32.dll,LockWorkStation`
- Unlock: Requires password (may need additional auth mechanism or user interaction)
- Clear Cache: PowerShell script to clear:
- Temp files: `Remove-Item $env:TEMP\* -Recurse -Force`
- Browser cache: Chrome, Edge, Firefox cache directories
- Windows temp: `C:\Windows\Temp\*`
- Buzz: Play system sound repeatedly using PowerShell `[console]::beep(frequency, duration)` or WAV file in loop, stop after duration expires
- Broadcast Message: Display via Toast notifications (`New-BurntToastNotification`) or PowerShell popup window
- **Android**:
- Lock: DeviceAdmin API `lockNow()`
- Unlock: Requires device password/pin (user must unlock manually)
- Clear Cache: `PackageManager.clearApplicationUserData()` or `clearCache()` for specific apps
- Buzz: Vibrate API `Vibrator.vibrate()` with pattern, use `VibrationEffect.createWaveform()` for custom patterns
- Broadcast Message: Notification API with persistent notification
- Create polling script/service that checks for commands/messages and executes/displays them

**Dashboard**:

- UI buttons in device details view (Lock Device, Unlock Device, Clear Cache, Buzz Device)
- Buzz duration selector (dropdown: 5s, 10s, 15s, 30s)
- Message composer interface for broadcast messages
- Device selection options for messages:
- Single device (dropdown)
- Location (all devices in location)
- All devices
- Command/message history/log viewer showing all commands and messages sent to device
- Status indicators for pending commands/messages (spinner/loading state)
- Confirmation dialogs before executing commands
- Expiration date/time picker for broadcast messages
- Delivery status tracking for messages

**Files to create**:

- `supabase/migrations/017_create_device_commands.sql` - Database migration (single table for commands and messages)
- `dashboard/src/components/DeviceControl.tsx` - Control buttons and message composer component
- `dashboard/src/components/DeviceControl.css` - Styling
- `osquery-agent/execute-commands.ps1` - Windows command/message execution script (single script)
- `android-agent/android-app/app/src/main/java/com/vigyanshaala/mdm/CommandService.java` - Android command/message service (single service)

**Files to modify**:

- `osquery-agent/osquery.conf` - Add command/message polling query (or separate scheduled task)
- `dashboard/src/components/AppInventory.tsx` - Add device control buttons
- `dashboard/src/App.tsx` - Add device control/messaging tab/menu item
- `android-agent/android-app/app/src/main/AndroidManifest.xml` - Add DeviceAdmin and notification permissions

---

## 7. Live Chat Support

**Goal**: Real-time chat communication between support center and devices.

**Database Changes**:

- Create new table: `chat_messages`
- Columns:
- `id` (UUID, PRIMARY KEY)
- `device_hostname` (TEXT, FK to devices.hostname)
- `sender` (TEXT: 'center'/'device')
- `message` (TEXT, NOT NULL)
- `timestamp` (TIMESTAMPTZ)
- `read_status` (BOOLEAN, default false)
- `sender_id` (UUID, FK to auth.users, if sender = 'center')

**Architecture**:

- **Real-time**: Use Supabase Realtime subscriptions for instant updates (preferred)
- **Fallback**: Agents poll every 10-15 seconds for new messages
- **Agent UI**:
- **Windows**: PowerShell GUI window using `System.Windows.Forms` or embedded web view showing chat interface
- **Android**: In-app chat screen/activity with RecyclerView
- **Dashboard**: Chat interface component with device selection, message list, and input field

**Implementation Steps**:

1. Set up Supabase Realtime for `chat_messages` table
2. Create chat UI component in dashboard (`ChatSupport.tsx`)
3. Build agent-side chat interface:

- Windows: PowerShell GUI or web view
- Android: Chat Activity with RecyclerView

4. Implement message polling/real-time sync in agents
5. Add read receipts (update read_status when message viewed)
6. Optional: Typing indicators, message timestamps, user avatars

**Files to create**:

- `supabase/migrations/018_create_chat_messages.sql` - Database migration (includes automatic cleanup trigger)
- `dashboard/src/components/ChatSupport.tsx` - Chat interface component
- `dashboard/src/components/ChatSupport.css` - Styling
- `osquery-agent/chat-interface.ps1` - Windows chat GUI script
- `android-agent/android-app/app/src/main/java/com/vigyanshaala/mdm/ChatActivity.java` - Android chat activity
- `android-agent/android-app/app/src/main/res/layout/activity_chat.xml` - Android chat layout

**Files to modify**:

- `dashboard/src/App.tsx` - Add chat support tab/menu item
- `supabase/migrations/018_create_chat_messages.sql` - Enable Realtime on table, add cleanup trigger
- `osquery-agent/osquery.conf` - Add chat polling (or separate scheduled task)
- `android-agent/android-app/app/src/main/AndroidManifest.xml` - Add chat activity

**Database Cleanup Trigger**:

- Add automatic cleanup trigger to `chat_messages` table
- Delete messages older than 10 days on every insert
- No scheduling needed - trigger fires automatically
- Trigger function: `CREATE OR REPLACE FUNCTION cleanup_old_chat_messages() RETURNS TRIGGER AS $$ BEGIN DELETE FROM chat_messages WHERE timestamp < NOW() - INTERVAL '10 days'; RETURN NEW; END; $$ LANGUAGE plpgsql;`
- Trigger: `CREATE TRIGGER cleanup_chat_messages_trigger AFTER INSERT ON chat_messages FOR EACH ROW EXECUTE FUNCTION cleanup_old_chat_messages();`

**Complexity**: HIGH - Requires bidirectional real-time communication and UI on devices

---

## Implementation Order

1. **Logo fix** (quick win)
2. **Parameter centralization with health tracking** (foundation for other work, includes Step 7 merged)
3. **Database migration** (add new parameters and device_health table)
4. **Excel export** (user-facing feature)
5. **Geofence fix - WiFi-based** (critical functionality)
6. **Android APK** (deployment)
7. **Device Control and Messaging** (remote management, includes Steps 8, 9, 10 merged)
8. **Live Chat Support** (most complex, requires real-time infrastructure)