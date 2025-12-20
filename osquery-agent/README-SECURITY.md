# Security and Lockdown Guide

## Preventing Uninstallation and Settings Changes

Students should not be able to:
- Uninstall osquery agent
- Stop/start the osquery service
- Modify osquery configuration
- Delete osquery files

## Implementation Steps

### 1. Run Lockdown Script (After Installation)

After installing osquery via MSI, run as Administrator:

```powershell
.\prevent-uninstall.ps1
```

This script:
- Restricts folder permissions (only Admins can modify)
- Locks service permissions (prevents stop/start by non-admins)
- Makes config file read-only
- Removes uninstall registry entries
- Creates watchdog task to auto-restart service

### 2. Windows Group Policy (Recommended for Domain)

If devices are domain-joined, use Group Policy:

**Computer Configuration → Policies → Administrative Templates → Windows Components → Windows Installer**

- Enable: "Prevent users from installing software"
- Enable: "Disable Windows Installer"

**Computer Configuration → Policies → Windows Settings → Security Settings → System Services**

- Set osqueryd service to: "Automatic" and "Prevent user from changing"

### 3. Local Security Policy (Standalone Devices)

For non-domain devices:

1. Run `secpol.msc` as Administrator
2. Navigate to: **Local Policies → User Rights Assignment**
3. Set "Load and unload device drivers" → Remove "Users"
4. Set "Shut down the system" → Remove "Users" (optional, may be too restrictive)

### 4. Registry Lock (Additional Protection)

Add to registry to prevent uninstallation:

```powershell
# Run as Administrator
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer" /v DisableUserInstalls /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer" /v DisableMSI /t REG_DWORD /d 0 /f
```

### 5. Chrome Policy Enforcement

To enforce website blocklist, deploy Chrome policy:

**Registry Path:** `HKLM\SOFTWARE\Policies\Google\Chrome\URLBlocklist`

Create policy JSON:
```json
{
  "URLBlocklist": [
    "facebook.com",
    "instagram.com",
    "*.tiktok.com"
  ]
}
```

Deploy via:
- Group Policy (if domain-joined)
- Registry directly (standalone)
- MDM solution

### 6. Software Installation Prevention

**Group Policy → Computer Configuration → Software Restriction Policies**

Create path rules to block:
- `C:\Users\*\AppData\Local\Temp\*.exe` (temp installers)
- `C:\Users\*\Downloads\*.exe` (downloaded installers)

Or use AppLocker (Windows Pro/Enterprise):
- Block execution from user directories
- Allow only signed/approved software

## Verification

Test that students cannot:
1. Uninstall from Programs and Features (should not appear)
2. Stop service: `sc stop osqueryd` (should fail with "Access Denied")
3. Delete osquery folder (should fail with "Access Denied")
4. Modify osquery.conf (should be read-only)

## Recovery

If you need to uninstall later:

1. Run as Administrator:
```powershell
# Re-enable uninstall
$uninstallKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*osquery*"
# Restore UninstallString if needed

# Remove service
sc.exe delete osqueryd

# Remove folder
Remove-Item "C:\Program Files\osquery" -Recurse -Force
```

## Best Practices

1. **Test on one device first** before deploying to all
2. **Document admin credentials** - you'll need them for changes
3. **Use Group Policy** if possible (easier to manage centrally)
4. **Monitor service status** via dashboard
5. **Create admin-only account** separate from student accounts




