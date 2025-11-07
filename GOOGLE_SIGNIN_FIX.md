# Google Sign-In Fix Guide

## Issues Identified and Solutions

### 1. Missing iOS Configuration File
**Problem**: No `GoogleService-Info.plist` file found in iOS directory
**Solution**: 
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project "cinephile-1e455"
3. Go to Project Settings > General
4. Add iOS app with bundle ID: `com.example.cinephile`
5. Download the `GoogleService-Info.plist` file
6. Place it in `ios/Runner/` directory
7. Add it to Xcode project (drag and drop into Runner folder)

### 2. SHA-1 Fingerprint Issue
**Problem**: The SHA-1 fingerprint in google-services.json might not match your current debug keystore
**Solution**:
1. Get your debug SHA-1 fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
2. Go to Firebase Console > Project Settings > General
3. Add this SHA-1 fingerprint to your Android app configuration
4. Download the updated `google-services.json` file
5. Replace the existing file in `android/app/`

### 3. Package Name Verification
**Current package name**: `com.example.cinephile`
**Action needed**: Verify this matches your Firebase project configuration

### 4. Additional Android Configuration
**Fixed**: Added internet permission to AndroidManifest.xml

### 5. Code Implementation Check
**Status**: ✅ Code implementation looks correct
- AuthService properly configured
- GoogleSignIn properly initialized
- Error handling in place

## Steps to Complete the Fix:

### Step 1: Get SHA-1 Fingerprint ✅ COMPLETED
**Your SHA-1 Fingerprint**: `92:29:77:52:EA:74:CE:32:4B:4F:05:1C:01:CF:12:26:A1:CD:8D:A0`

For Windows users, if the debug keystore doesn't exist, create it first:
```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Then get the SHA-1:
```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### Step 2: Update Firebase Configuration ⚠️ REQUIRED
**Current certificate hash in google-services.json**: `c810c40eb580b87cab95f0ac0ac0c5d9b353c262`
**Your new SHA-1 fingerprint**: `92:29:77:52:EA:74:CE:32:4B:4F:05:1C:01:CF:12:26:A1:CD:8D:A0`

**These don't match! This is why Google Sign-In is failing.**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project "cinephile-1e455"
3. Go to Project Settings → General
4. Find your Android app and click "Add fingerprint"
5. Add this SHA-1 fingerprint: `92:29:77:52:EA:74:CE:32:4B:4F:05:1C:01:CF:12:26:A1:CD:8D:A0`
6. Download the updated `google-services.json` file
7. Replace `android/app/google-services.json` with the new file

### Step 3: Add iOS Configuration
1. Add iOS app in Firebase Console with bundle ID `com.example.cinephile`
2. Download `GoogleService-Info.plist`
3. Place in `ios/Runner/` directory
4. Add to Xcode project

### Step 4: Test the Implementation
1. Clean and rebuild your project:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Common Error Messages and Solutions:

### "Sign in failed" or "Google sign-in failed"
- Check SHA-1 fingerprint matches Firebase configuration
- Verify package name consistency
- Ensure internet permission is granted

### "PlatformException" errors
- Verify google-services.json is in correct location
- Check that Google Services plugin is applied
- Ensure all dependencies are up to date

### iOS-specific errors
- Verify GoogleService-Info.plist is added to Xcode project
- Check bundle identifier matches Firebase configuration
- Ensure URL schemes are configured in Info.plist

## Verification Checklist:
- [ ] SHA-1 fingerprint added to Firebase
- [ ] Updated google-services.json downloaded and placed correctly
- [ ] GoogleService-Info.plist added to iOS project
- [ ] Internet permission added to AndroidManifest.xml
- [ ] Package name consistent across all configurations
- [ ] Project cleaned and rebuilt

After completing these steps, Google Sign-In should work properly on both Android and iOS platforms.
