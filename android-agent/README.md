# VigyanShaala MDM - Android Installer

This package provides the same MDM features for Android devices:
- Device enrollment and monitoring
- Website blocking (via DNS/VPN)
- App blocking (restrict installation of blocked apps)
- Automatic policy sync

## Installation

### Option 1: Direct APK Installation (Recommended)
1. Download the `VigyanShaala-MDM-Android.apk` file
2. Enable "Install from Unknown Sources" on your Android device
3. Install the APK
4. Open the app and complete enrollment

### Option 2: Via ADB (For bulk deployment)
```bash
adb install VigyanShaala-MDM-Android.apk
```

## Features

### Device Enrollment
- Collects device information (model, serial, Android version)
- Registers device with MDM server
- Connects to Supabase backend

### Website Blocking
- Uses Android's Private DNS or VPN API to block domains
- Blocks websites across all browsers (Chrome, Firefox, Samsung Internet, etc.)
- Syncs blocklist from server every 30 minutes

### App Blocking
- Prevents installation of blocked apps via Package Installer
- Removes already-installed blocked apps
- Checks and enforces policies hourly

### Automatic Sync
- Website blocklist syncs every 30 minutes
- App blocklist checks every hour
- Device status updates every 15 minutes

## Requirements

- Android 8.0 (API 26) or higher
- Device Admin permissions (for app blocking)
- Network access to Supabase server

## Configuration

The app will prompt for Supabase credentials during enrollment, or you can pre-configure them in the APK.

## Uninstallation

Go to Settings > Apps > VigyanShaala MDM > Uninstall
Note: Removing the app will also remove all blocking policies.

