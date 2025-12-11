# Website Blocking Implementation

## How It Works

The website blocking feature uses a **hybrid approach** combining:
1. **Browser-specific policies** (Chrome & Edge) via Windows Registry
2. **Windows Hosts file** (blocks ALL browsers and applications) at OS level

When you add a domain to the blocklist in the dashboard, it's automatically synced to all enrolled devices.

### How to Use

1. **Add domains to blocklist** in the dashboard (Website Blocklist section)
2. **Wait up to 30 minutes** - the blocklist syncs automatically every 30 minutes
3. **Changes take effect immediately** - no browser restart needed!

### Manual Sync (if needed)

To manually sync the blocklist immediately on a device:

```powershell
# Run as Administrator
cd "C:\Program Files\osquery"
.\apply-website-blocklist.ps1
```

### Technical Details

**Browser Policies:**
- Chrome: `HKLM:\SOFTWARE\Policies\Google\Chrome\URLBlocklist`
- Edge: `HKLM:\SOFTWARE\Policies\Microsoft\Edge\URLBlocklist`

**Hosts File:**
- Location: `C:\Windows\System32\drivers\etc\hosts`
- Format: `0.0.0.0 domain.com` (redirects to invalid IP)
- Blocks: ALL browsers, applications, and network requests

**Sync:**
- Frequency: Every 30 minutes via Windows Scheduled Task
- Automatic DNS cache flush after update
- No user action required

**Requires:** Administrator privileges (script runs as SYSTEM via scheduled task)

### What Gets Blocked

✅ **All browsers:**
- Google Chrome
- Microsoft Edge
- Mozilla Firefox
- Opera
- Safari
- Brave
- Any other browser

✅ **All applications:**
- Games
- Chat applications
- Media players
- Any app that uses internet

### Advantages

1. **Universal blocking** - Works for all browsers and apps
2. **Immediate effect** - No browser restart needed
3. **Hard to bypass** - Requires admin access to edit hosts file
4. **Automatic sync** - Updates every 30 minutes in background
5. **Dual protection** - Browser policies + Hosts file

### Limitations

1. **Admin access required** - Users with admin rights can edit hosts file
2. **30-minute delay** - Maximum time before changes take effect
3. **Hosts file size** - Limited to ~500KB (typically not an issue)
4. **DNS cache** - May need manual flush on rare occasions

