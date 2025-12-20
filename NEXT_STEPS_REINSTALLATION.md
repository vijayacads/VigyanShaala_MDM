# Next Steps: Reinstallation Process

## ✅ What You've Completed

- ✅ All SQL migrations run (015, 017, 018)
- ✅ Edge functions deployed
- ✅ All code implemented

## 🎯 What to Do Now

### Step 1: Create New Installer Package

**Run this command** (replace with your Supabase credentials):

```powershell
cd osquery-agent
.\create-installer-package.ps1 -SupabaseUrl "YOUR_SUPABASE_URL" -SupabaseAnonKey "YOUR_SUPABASE_KEY"
```

This creates: `VigyanShaala-MDM-Installer.zip` with all new components.

### Step 2: Copy Package to Dashboard

1. Copy the ZIP file to:
   ```
   dashboard/public/downloads/VigyanShaala-MDM-Installer.zip
   ```

2. If you've built the dashboard, also copy to:
   ```
   dashboard/dist/downloads/VigyanShaala-MDM-Installer.zip
   ```

### Step 3: For Each Existing Device

#### Option A: Use Uninstall Script (Recommended)

1. **Download uninstall script** from the old installer or use:
   - `osquery-agent/uninstall-osquery.ps1`

2. **Run as Administrator**:
   ```powershell
   .\uninstall-osquery.ps1
   ```

3. **Confirm uninstallation**

#### Option B: Manual Uninstall

1. Stop osquery service
2. Uninstall via Windows Programs
3. Remove scheduled tasks
4. Delete installation directory

**See `REINSTALLATION_GUIDE.md` for detailed uninstall steps.**

### Step 4: Install New Package

1. **Download** from dashboard → Device Software Downloads
2. **Extract** the ZIP file
3. **Right-click** `RUN-AS-ADMIN.bat` → **Run as Administrator**
4. **Follow prompts** - installation is automatic
5. **Complete enrollment** when wizard appears

### Step 5: Verify Installation

Check these are working:

- ✅ osquery service running
- ✅ 4 scheduled tasks created (including new CommandProcessor)
- ✅ Device appears in dashboard
- ✅ Health data appears after 10-15 minutes
- ✅ Device control works (test with "Clear Cache")
- ✅ Chat works (optional)

---

## 📋 Quick Checklist

- [ ] Create new installer package
- [ ] Copy package to dashboard downloads folder
- [ ] Uninstall existing installations on devices
- [ ] Download new package from dashboard
- [ ] Install on each device
- [ ] Verify all features working

---

## 📚 Reference Documents

- **`REINSTALLATION_GUIDE.md`** - Detailed step-by-step reinstallation guide
- **`CREATE_NEW_INSTALLER_PACKAGE.md`** - How to create the installer package
- **`IMPLEMENTATION_COMPLETE.md`** - Full implementation details

---

## 🚀 Quick Start Commands

### Create Installer:
```powershell
cd osquery-agent
.\create-installer-package.ps1 -SupabaseUrl "https://xxxxx.supabase.co" -SupabaseAnonKey "your-key-here"
```

### Uninstall (on device):
```powershell
.\uninstall-osquery.ps1
```

### Install (on device):
```powershell
# Extract ZIP, then:
.\RUN-AS-ADMIN.bat
```

---

**You're ready to proceed!** Start with Step 1 above. 🎉




