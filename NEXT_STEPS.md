# Next Steps for VigyanShaala MDM Platform

## ✅ Completed Tasks

1. ✅ Database schema created (locations, devices, software_inventory, web_activity)
2. ✅ Dummy data seeded (5 computers with software and activity)
3. ✅ Dashboard UI components built (map, inventory, alerts, blocklists)
4. ✅ Supabase connection configured
5. ✅ OSQuery agent installer scripts created

---

## 🔄 Immediate Next Steps

### 1. Supabase Setup & Verification

**Priority: HIGH**

1. **Run Database Migrations:**
   - Go to Supabase Dashboard → SQL Editor
   - Run migrations in order:
     - `supabase/migrations/001_locations.sql`
     - `supabase/migrations/002_devices.sql`
     - `supabase/migrations/003_software_web_activity.sql`
     - `supabase/migrations/004_seed_dummy_devices.sql`

2. **Configure Row Level Security (RLS):**
   - For testing, temporarily disable RLS (see `supabase/SETUP_INSTRUCTIONS.md`)
   - Or create admin user with proper role metadata

3. **Get API Credentials:**
   - Settings → API
   - Copy Project URL and anon key

4. **Configure Dashboard:**
   ```bash
   cd dashboard
   cp .env.example .env
   # Edit .env with your Supabase credentials
   npm install
   npm run dev
   ```

5. **Verify Data Loading:**
   - Dashboard should show 5 devices
   - Map should display device locations
   - Inventory table should show software

---

### 2. FleetDM Integration (Optional but Recommended)

**Priority: MEDIUM**

FleetDM provides centralized osquery management. If using:

1. **Set up FleetDM Server:**
   - Deploy FleetDM (Docker or cloud)
   - Configure enrollment tokens
   - Set up API access

2. **Update Enrollment Script:**
   - Modify `osquery-agent/enroll-fleet.ps1`
   - Add FleetDM enrollment API calls
   - Link `fleet_uuid` to Supabase device records

3. **Configure osquery.conf:**
   - Point to FleetDM server
   - Enable FleetDM tls plugin

**Alternative:** Use direct Supabase approach without FleetDM (simpler, but less centralized management)

---

### 3. OSQuery Agent Deployment

**Priority: HIGH**

1. **Test Installation:**
   - Run `osquery-agent/install-osquery.ps1` on a test computer
   - Verify enrollment flow works
   - Check device appears in dashboard

2. **Create MSI Package (For Production):**
   - Use WiX Toolset or similar
   - Bundle osquery MSI + config files
   - Include post-install enrollment script
   - Test silent installation

3. **Deployment Strategy:**
   - **Option A:** Manual installation per device
   - **Option B:** Group Policy deployment (Windows domain)
   - **Option C:** Remote management tool (SCCM, Intune, etc.)

---

### 4. Edge Functions Deployment

**Priority: MEDIUM**

Deploy Supabase Edge Functions for automated processing:

1. **Geofence Alert Function:**
   ```bash
   supabase functions deploy geofence-alert
   ```
   - Processes GPS data from devices
   - Checks against location geofences
   - Creates alerts when devices leave bounds

2. **Fetch OSQuery Data Function:**
   ```bash
   supabase functions deploy fetch-osquery-data
   ```
   - Pulls data from FleetDM (if used)
   - Updates device inventory in Supabase

3. **Blocklist Sync Function:**
   ```bash
   supabase functions deploy blocklist-sync
   ```
   - Syncs blocklist rules to devices
   - Triggers osquery policy updates

**Setup:**
- Install Supabase CLI
- Login: `supabase login`
- Link project: `supabase link --project-ref your-project-ref`
- Deploy functions

---

### 5. Real-time Data Collection

**Priority: HIGH**

Currently using dummy/static data. Need to establish real-time collection:

1. **GPS/Location Updates:**
   - Configure osquery to collect location every 5 minutes
   - Send to Supabase via Edge Function or direct API
   - Update `devices.latitude` and `devices.longitude`

2. **Software Inventory:**
   - osquery query: `SELECT * FROM programs;`
   - Schedule in osquery.conf (every 1 hour)
   - Insert/update `software_inventory` table

3. **Web Activity:**
   - Use browser extensions or osquery events
   - Log to `web_activity` table
   - Real-time updates via Supabase subscriptions

4. **Device Status:**
   - Heartbeat query: Update `devices.last_seen`
   - System info: Update `devices.os_version`, etc.

---

### 6. Authentication & Authorization

**Priority: MEDIUM**

Currently in demo mode. Implement proper auth:

1. **Supabase Auth Setup:**
   - Enable email/password or OAuth providers
   - Create admin and teacher user roles
   - Set up role-based access control

2. **Dashboard Authentication:**
   - Add login page
   - Integrate Supabase Auth
   - Implement role-based UI (teachers see only their location)

3. **API Security:**
   - Ensure RLS policies are correct
   - Test that teachers can't access other locations
   - Verify admin permissions

---

### 7. Blocklist Enforcement

**Priority: MEDIUM**

Currently blocklists are stored but not enforced:

1. **Software Blocklist:**
   - Create osquery query to detect blocked software
   - Trigger alert or action when detected
   - Optionally auto-uninstall (requires admin privileges)

2. **Website Blocklist:**
   - Browser extension or proxy configuration
   - Log blocked access attempts
   - Display violations in dashboard

3. **Policy Deployment:**
   - Edge Function to sync blocklists to devices
   - Update osquery.conf dynamically
   - Real-time policy updates

---

### 8. Dashboard Enhancements

**Priority: LOW**

1. **Device Details Page:**
   - Individual device view
   - Software inventory per device
   - Web activity timeline
   - Compliance history

2. **Reporting:**
   - Compliance reports
   - Activity summaries
   - Export to CSV/PDF

3. **Notifications:**
   - Email alerts for geofence violations
   - Dashboard notifications
   - SMS integration (optional)

---

### 9. Production Hardening

**Priority: HIGH (Before Production)**

1. **Security:**
   - Enable and test RLS properly
   - Secure API keys (never commit to git)
   - Implement rate limiting
   - Audit logging

2. **Performance:**
   - Database indexing (already done in migrations)
   - Query optimization
   - Caching strategy

3. **Monitoring:**
   - Error tracking (Sentry, etc.)
   - Performance monitoring
   - Uptime monitoring

4. **Backup & Recovery:**
   - Database backups
   - Disaster recovery plan

---

### 10. Testing & Validation

**Priority: HIGH**

1. **Unit Tests:**
   - Dashboard components
   - API endpoints
   - Edge Functions

2. **Integration Tests:**
   - End-to-end enrollment flow
   - Data collection pipeline
   - Alert generation

3. **Load Testing:**
   - Test with 100+ devices
   - Verify dashboard performance
   - Database query performance

---

## 🚀 Deployment Checklist

Before deploying to production:

- [ ] All migrations run successfully
- [ ] Dashboard connects to Supabase
- [ ] Dummy data visible in dashboard
- [ ] OSQuery agent installs successfully
- [ ] Enrollment flow works
- [ ] Device appears in dashboard after enrollment
- [ ] Real-time updates working (if implemented)
- [ ] RLS policies tested and working
- [ ] Authentication implemented
- [ ] Edge Functions deployed
- [ ] Error handling in place
- [ ] Logging configured
- [ ] Backup strategy defined
- [ ] Documentation complete

---

## 📚 Documentation Needs

- [ ] Installation guide for administrators
- [ ] Teacher enrollment guide
- [ ] Troubleshooting guide
- [ ] API documentation
- [ ] Architecture diagram
- [ ] Security best practices

---

## 🎯 Quick Start for Testing

1. **Set up Supabase:**
   ```bash
   # Run migrations in SQL Editor
   # Get API credentials
   ```

2. **Run Dashboard:**
   ```bash
   cd dashboard
   cp .env.example .env
   # Add Supabase credentials to .env
   npm install
   npm run dev
   ```

3. **Test on One Device:**
   ```powershell
   cd osquery-agent
   .\install-osquery.ps1 -SupabaseUrl "..." -SupabaseKey "..."
   ```

4. **Verify in Dashboard:**
   - Device should appear
   - Map should show location
   - Inventory should populate

---

## 📞 Support & Resources

- **Supabase Docs:** https://supabase.com/docs
- **OSQuery Docs:** https://osquery.readthedocs.io
- **FleetDM Docs:** https://fleetdm.com/docs
- **React Dashboard:** See `dashboard/README.md`
- **Agent Installer:** See `osquery-agent/INSTALLER_README.md`
