# How to Build the Android APK

## Prerequisites

1. **Android Studio** (latest version) - Download from https://developer.android.com/studio
2. **Java JDK 17 or higher** (usually included with Android Studio)
3. **Android SDK** (installed via Android Studio)

## Step-by-Step Build Instructions

### 1. Install Android Studio

Download and install Android Studio from the official website. During installation:
- Install Android SDK
- Install Android SDK Platform-Tools
- Install Android Emulator (optional, for testing)

### 2. Open the Project

1. Open Android Studio
2. Click "Open" or "Open an Existing Project"
3. Navigate to: `android-agent/android-app/`
4. Click "OK"

Android Studio will sync the project and download dependencies (this may take a few minutes).

### 3. Configure Build Settings (if needed)

1. Go to File > Project Structure
2. Ensure:
   - **Compile SDK Version**: 34
   - **Min SDK Version**: 26 (Android 8.0)
   - **Target SDK Version**: 34
   - **Build Tools Version**: Latest

### 4. Build the APK

#### Option A: Build via Menu
1. Go to **Build > Build Bundle(s) / APK(s) > Build APK(s)**
2. Wait for build to complete
3. Click "locate" when build finishes
4. APK will be in: `android-app/app/build/outputs/apk/debug/app-debug.apk`

#### Option B: Build via Command Line
```bash
cd android-agent/android-app
./gradlew assembleDebug
```

For Windows:
```cmd
cd android-agent\android-app
gradlew.bat assembleDebug
```

APK location: `app/build/outputs/apk/debug/app-debug.apk`

### 5. Build Release APK (for distribution)

1. Go to **Build > Generate Signed Bundle / APK**
2. Select **APK**
3. Create a new keystore (or use existing):
   - Click "Create new..."
   - Choose location and password
   - Fill in certificate details
   - Click OK
4. Select the keystore and enter password
5. Select **release** build variant
6. Click **Finish**

Release APK location: `app/build/outputs/apk/release/app-release.apk`

### 6. Rename and Package

Rename the APK to `VigyanShaala-MDM-Android.apk` and include it in the installer ZIP.

## Troubleshooting

**"SDK not found" error:**
- Open SDK Manager (Tools > SDK Manager)
- Install required SDK packages

**"Gradle sync failed":**
- Go to File > Settings > Build > Gradle
- Check "Use Gradle from: specified location" and select Gradle wrapper
- Or update Gradle version in `gradle/wrapper/gradle-wrapper.properties`

**Build errors:**
- Clean project: Build > Clean Project
- Rebuild: Build > Rebuild Project
- Invalidate caches: File > Invalidate Caches / Restart

## Testing

1. Connect Android device via USB (enable USB debugging)
2. Click Run button in Android Studio
3. Select your device
4. App will install and launch

Or use Android Emulator:
1. Tools > Device Manager
2. Create a virtual device
3. Run the app




