# OSQuery Agent Installation Architecture

## Overview

**Central System (Cloud):**
- Supabase (Database + API)
- Dashboard (Render/Vercel)
- Optional: FleetDM Server

**Field Devices (Windows Laptops):**
- osquery agent (installed locally)
- Enrollment script (runs once)
- osquery.conf (configuration file)

---

## Installation Flow

### 1. **Central Setup (One-time, Admin)**

**On Central Server/Cloud:**
- Supabase database already set up
- Locations table populated (5+ school locations)
- Dashboard deployed
- Environment variables configured

**What Admin Prepares:**
- Supabase URL and API key
- Optional: FleetDM server URL
- MSI installer package (if using enterprise deployment)

---

### 2. **Field Device Installation (Per Device)**

#### Step A: Install osquery Agent

**On Each Windows Laptop:**

```powershell
# Option 1: Automated script
.\install-osquery.ps1 -SupabaseUrl "https://xxx.supabase.co" -SupabaseKey "xxx"

# Option 2: Manual
# 1. Download osquery MSI from osquery.io
# 2. Run MSI installer
# 3. osquery installed at: C:\Program Files\osquery\
```

**What Happens:**
- osquery binary installed
- Windows service `osqueryd` created
- Config directory created
- Logs directory created

---

#### Step B: Configuration

**Environment Variables Set:**
```powershell
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx
FLEET_SERVER_URL=https://fleet.example.com (optional)
```

**Configuration File:**
- `osquery.conf` copied to `C:\Program Files\osquery\osquery.conf`
- Contains scheduled queries (GPS, software inventory, etc.)
- Queries run every X minutes/hours

---

#### Step C: Enrollment (First-Time Setup)

**When enrollment script runs:**

1. **Device Collects Info:**
   ```
   - Hostname (e.g., "PC-LAB-001")
   - Serial Number (e.g., "SN123456789")
   - OS Version (e.g., "10.0.19045")
   - MAC Address (optional)
   ```

2. **Fetches Locations from Supabase:**
   ```
   GET https://xxx.supabase.co/rest/v1/locations?is_active=eq.true
   Returns: List of all active school locations
   ```

3. **Shows GUI to Teacher:**
   ```
   Dropdown menu appears:
   - Pune School 1 (Radius: 500m)
   - Mumbai School 1 (Radius: 500m)
   - Delhi School 1 (Radius: 500m)
   ...
   ```

4. **Teacher Selects Location:**
   - Clicks on their school
   - Clicks "Enroll" button

5. **Device Registers in Supabase:**
   ```json
   POST https://xxx.supabase.co/rest/v1/devices
   {
     "hostname": "PC-LAB-001",
     "serial_number": "SN123456789",
     "location_id": "uuid-of-selected-location",
     "os_version": "10.0.19045",
     "compliance_status": "unknown"
   }
   ```

6. **Device Gets Assigned ID:**
   - Supabase returns device record
   - Device ID: 100001 (6-digit integer)
   - Enrollment complete!

---

### 3. **Ongoing Operation (After Installation)**

#### On Field Device:

**osquery Service Runs Continuously:**

1. **Every 5 minutes:**
   ```sql
   -- Query GPS/location (if available)
   SELECT latitude, longitude FROM ...
   ```

2. **Every 1 hour:**
   ```sql
   -- Query installed software
   SELECT name, version, path FROM programs
   ```

3. **Real-time:**
   ```sql
   -- Query web browser activity (if configured)
   SELECT url, domain FROM ...
   ```

4. **Data Sent to Supabase:**
   ```json
   POST /rest/v1/software_inventory
   POST /rest/v1/web_activity
   PATCH /rest/v1/devices (update last_seen, GPS, etc.)
   ```

---

#### On Central Dashboard:

**Real-time Monitoring:**

1. **Dashboard Queries Supabase:**
   ```sql
   SELECT * FROM devices WHERE location_id = 'xxx'
   ```

2. **Supabase Realtime Subscriptions:**
   - Dashboard subscribes to `devices` table changes
   - When field device updates data → Dashboard auto-updates
   - No polling needed!

3. **Display:**
   - Map shows device locations
   - Table shows device inventory
   - Alerts show geofence violations

---

## Data Flow Diagram

```
┌─────────────────┐
│  Field Device   │
│  (Windows PC)   │
│                 │
│  1. osquery     │──┐
│  2. enrollment  │  │
│  3. collects    │  │  HTTP/REST
│     data        │  │  API Calls
└─────────────────┘  │
                     │
                     ▼
            ┌────────────────┐
            │    Supabase    │
            │   (Database)   │
            │                │
            │  - devices     │
            │  - locations   │
            │  - software    │
            │  - web_activity│
            └────────────────┘
                     │
                     │ Realtime
                     │ Subscriptions
                     ▼
            ┌────────────────┐
            │   Dashboard    │
            │    (Render)    │
            │                │
            │  - Shows map   │
            │  - Lists devices│
            │  - Alerts      │
            └────────────────┘
```

---

## Key Points

### **No Direct Connection Between Devices**
- Field devices don't connect to each other
- All communication goes through Supabase
- Central dashboard doesn't connect to devices directly

### **Push Model (Devices → Cloud)**
- osquery on device pushes data to Supabase
- No central server pulling from devices
- Each device is independent

### **Location Assignment Happens Once**
- During enrollment, teacher picks location
- Device gets `location_id` stored in Supabase
- Geofencing automatically configured

### **Central Admin View**
- Admin can see ALL devices in dashboard
- Teachers see only their location (via RLS)
- No need to manage device connections

---

## Deployment Scenarios

### **Scenario 1: Manual Installation**
- IT admin visits each school
- Runs installer on each laptop
- Teacher selects location during enrollment
- 100 devices = 100 manual installations

### **Scenario 2: MSI Package**
- Admin creates MSI with embedded config
- Distributes via USB/network share
- Teacher runs MSI, selects location
- Automated installation

### **Scenario 3: Group Policy (Enterprise)**
- Admin pushes MSI via Windows Group Policy
- Devices auto-install on domain join
- Enrollment script runs on first login
- Mass deployment possible

### **Scenario 4: Remote Management**
- SCCM/Intune pushes MSI package
- Devices install automatically
- Enrollment via script or MDM tool
- Centralized management

---

## Security & Privacy

### **Device Side:**
- osquery runs as Windows service
- Only collects system information
- No remote control/access
- Data encrypted in transit (HTTPS)

### **Central Side:**
- RLS policies restrict data access
- Teachers see only their location
- Admins see all devices
- API keys secure (never exposed to teachers)

---

## Troubleshooting Flow

**If Device Doesn't Appear in Dashboard:**

1. Check enrollment completed
   ```sql
   SELECT * FROM devices WHERE hostname = 'PC-LAB-001';
   ```

2. Check osquery service running
   ```powershell
   Get-Service osqueryd
   ```

3. Check logs
   ```
   C:\Program Files\osquery\log\osqueryd.results.log
   ```

4. Check Supabase connection
   ```powershell
   # Test API call
   Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/devices" -Headers @{"apikey"="$SUPABASE_KEY"}
   ```

---

## Summary

- **Central**: Supabase database + Dashboard (cloud)
- **Field**: osquery agent installed on each laptop
- **Connection**: Devices → Supabase (push data)
- **Dashboard**: Supabase → Dashboard (pull/real-time)
- **No peer-to-peer**: All goes through Supabase
