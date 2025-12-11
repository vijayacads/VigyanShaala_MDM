# Website Blocking Implementation

## How It Works

The website blocking feature uses **Chrome's URLBlocklist policy** via Windows Registry. When you add a domain to the blocklist in the dashboard, it's automatically synced to all enrolled devices.

### How to Use

1. **Add domains to blocklist** in the dashboard (Website Blocklist section)
2. **Wait 30 minutes** (or run sync manually) - the blocklist syncs automatically every 30 minutes
3. **Users must restart Chrome** for the blocklist to take effect

### Manual Sync (if needed)

To manually sync the blocklist immediately on a device:

```powershell
# Run as Administrator
cd "C:\Program Files\osquery"
.\apply-website-blocklist.ps1
```

### Technical Details

- **Registry Path**: `HKLM:\SOFTWARE\Policies\Google\Chrome\URLBlocklist`
- **Sync Frequency**: Every 30 minutes via Windows Scheduled Task
- **Scope**: All Chrome browsers on the device (per-user policies also work)
- **Requires**: Administrator privileges to modify registry

### Limitations

1. **Chrome only** - This only blocks websites in Google Chrome
2. **Users can use other browsers** - Edge, Firefox, etc. are not blocked
3. **Admin rights required** - Policy is applied at system level
4. **Chrome restart needed** - Users must restart Chrome after policy is applied

### Future Improvements

- Add Edge browser blocking
- Add Firefox blocking
- Add system-level proxy blocking (blocks all browsers)
- Real-time sync (instead of 30-minute interval)

