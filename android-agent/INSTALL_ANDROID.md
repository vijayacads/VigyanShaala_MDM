# Android MDM Installation Guide

## Quick Start

1. **Download the installer package**
   - Get `VigyanShaala-MDM-Android.apk` from the dashboard
   - Or download the full ZIP package

2. **Install on Android device**
   - Transfer APK to device (via USB, email, or download)
   - Enable "Install from Unknown Sources" in Android settings
   - Tap the APK file to install
   - Grant Device Admin permissions when prompted

3. **Complete enrollment**
   - Open the VigyanShaala MDM app
   - Enter Supabase URL and API key (provided by admin)
   - Fill in device details (hostname, inventory code, location, etc.)
   - Tap "Register Device"

4. **Done!**
   - Website blocking will activate automatically
   - App blocking will be enforced
   - Device will appear in dashboard

## Features Included

✅ **Website Blocking**
- Blocks domains via Private DNS or VPN
- Works across all browsers
- Updates automatically every 30 minutes

✅ **App Blocking**
- Prevents installation of blocked apps
- Removes already-installed blocked apps
- Enforces policies every hour

✅ **Device Monitoring**
- Reports device location (GPS)
- Reports installed apps
- Reports browser activity
- Updates dashboard in real-time

## Troubleshooting

**Installation fails:**
- Enable "Unknown Sources" in Security settings
- Grant storage permissions to file manager
- Check Android version (requires 8.0+)

**Blocking not working:**
- Grant Device Admin permissions
- Check network connection to Supabase
- Verify Supabase URL and API key

**Device not appearing in dashboard:**
- Check enrollment was completed successfully
- Verify device has internet connection
- Check Supabase credentials are correct




