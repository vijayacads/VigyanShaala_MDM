# Next Steps After Render Update

## ✅ What You've Done
- [x] Created new Supabase project: `thqinhphunrflwlshdmx`
- [x] Ran `FRESH_START_COMPLETE_SETUP.sql` in new project
- [x] Updated Render with new Supabase credentials

## 📋 Next Steps Checklist

### 1. Verify Render Environment Variables
Go to Render Dashboard → Your Service → Environment tab

**Required Variables:**
```
VITE_SUPABASE_URL=https://thqinhphunrflwlshdmx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM
NODE_ENV=production
PORT=3000
```

**Action:** Verify these match your new project exactly

---

### 2. Create Admin User in New Supabase Project

**Option A: Via Dashboard (Easiest)**
1. Go to: https://thqinhphunrflwlshdmx.supabase.co
2. Navigate to **Authentication** → **Users**
3. Click **"Add User"** → **"Create new user"**
4. Fill in:
   - **Email:** `Digital_Delivery@vigyanshaala.org`
   - **Password:** `VS_Digital_Delivery`
   - ✅ Check **"Auto Confirm User"**
5. Click **"Create User"**
6. Then run this SQL to set admin role:
   ```sql
   UPDATE auth.users 
   SET raw_user_meta_data = jsonb_build_object('role', 'admin')
   WHERE email = 'Digital_Delivery@vigyanshaala.org';
   ```

**Option B: Via SQL (if you have service_role access)**
Run the SQL from `supabase/migrations/023_create_admin_user.sql`

---

### 3. Test Dashboard Login
1. Go to your Render dashboard URL
2. Try logging in with:
   - **Username:** `Digital_Delivery`
   - **Password:** `VS_Digital_Delivery`
3. Verify you can see the dashboard

---

### 4. Create New Installer Package with New Credentials

**Run this in PowerShell:**
```powershell
cd osquery-agent
.\create-installer-package.ps1 `
    -SupabaseUrl "https://thqinhphunrflwlshdmx.supabase.co" `
    -SupabaseKey "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM"
```

**This will create:**
- `VigyanShaala-MDM-Installer.zip` in `osquery-agent/` folder
- Copy it to `dashboard/public/downloads/` for dashboard download

---

### 5. Update Dashboard Download Link (if needed)

The installer should be at:
```
dashboard/public/downloads/VigyanShaala-MDM-Installer.zip
```

**Verify:**
- File exists
- File is not empty
- Contains all required scripts

---

### 6. Test Device Enrollment

1. **Download installer** from dashboard (or use the ZIP you created)
2. **Extract** on a test Windows machine
3. **Run** `RUN-AS-ADMIN.bat` (right-click → Run as Administrator)
4. **Fill enrollment form**
5. **Check dashboard** - device should appear in devices table

---

### 7. Test Device Commands (Lock, Buzz, Clear Cache)

1. **Enroll a test device** (step 6)
2. **In dashboard**, select the device
3. **Send commands:**
   - Lock
   - Buzz
   - Clear Cache
4. **Verify commands execute** on the device

---

### 8. Verify Realtime is Working

**Check in Supabase:**
1. Go to **Database** → **Replication**
2. Verify `device_commands` table is listed
3. If not, run:
   ```sql
   ALTER PUBLICATION supabase_realtime ADD TABLE device_commands;
   ```

**Test on device:**
- Send a command from dashboard
- Check device logs: `$env:TEMP\VigyanShaala-RealtimeListener.log`
- Should see INSERT event received

---

### 9. Update Git Repository (Optional)

If you want to commit the new installer:
```powershell
git add dashboard/public/downloads/VigyanShaala-MDM-Installer.zip
git commit -m "Update installer with new Supabase project credentials"
git push
```

---

## 🔍 Verification Checklist

- [ ] Render dashboard loads correctly
- [ ] Can login with admin credentials
- [ ] Can see devices table (empty initially)
- [ ] Installer package created successfully
- [ ] Installer package is in `dashboard/public/downloads/`
- [ ] Test device enrollment works
- [ ] Device appears in dashboard after enrollment
- [ ] Device commands work (lock, buzz, clear_cache)
- [ ] Realtime listener receives commands
- [ ] All tables show correct RLS status in Supabase

---

## 🐛 Troubleshooting

**Dashboard not loading:**
- Check Render environment variables
- Check Render build logs for errors
- Verify Supabase URL/key are correct

**Can't login:**
- Verify admin user was created
- Check user metadata has `role: admin`
- Try clearing browser cache

**Device enrollment fails:**
- Check `enroll_device` function exists
- Verify RLS policies allow anonymous INSERT
- Check device logs for errors

**Commands not working:**
- Verify Realtime is enabled for `device_commands`
- Check device has `realtime-command-listener.ps1` running
- Check device logs: `$env:TEMP\VigyanShaala-RealtimeListener.log`

---

## 📝 Quick Reference

**New Supabase Project:**
- **URL:** `https://thqinhphunrflwlshdmx.supabase.co`
- **Anon Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRocWluaHBodW5yZmx3bHNoZG14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4Njk2ODcsImV4cCI6MjA4MTQ0NTY4N30.nVTHifwIDIozcqerE-X7zmebO6Pag8Ji-N3d4jetaQM`

**Admin Credentials:**
- **Email:** `Digital_Delivery@vigyanshaala.org`
- **Password:** `VS_Digital_Delivery`


