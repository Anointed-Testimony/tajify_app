# Android App Signing Setup for Play Store

This guide will help you set up app signing for uploading to the Google Play Store.

## Step 1: Generate the Keystore

Run the following command in your terminal (from the `tajify_app/android` directory):

```bash
keytool -genkey -v -keystore tajify-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tajify-key
```

You will be prompted to enter:
- **Keystore password**: Choose a strong password (you'll need this later)
- **Key password**: You can use the same password or a different one
- **Your name and organization details**: Fill in the required information

**Important**: 
- Keep the keystore file (`tajify-release-key.jks`) and passwords safe!
- If you lose the keystore file or forget the passwords, you won't be able to update your app on the Play Store.
- Store a backup of the keystore file in a secure location.

## Step 2: Update key.properties

Edit the `android/key.properties` file and replace the placeholder values:

```properties
storePassword=YOUR_ACTUAL_KEYSTORE_PASSWORD
keyPassword=YOUR_ACTUAL_KEY_PASSWORD
keyAlias=tajify-key
storeFile=../tajify-release-key.jks
```

Replace:
- `YOUR_ACTUAL_KEYSTORE_PASSWORD` with the keystore password you entered
- `YOUR_ACTUAL_KEY_PASSWORD` with the key password you entered

## Step 3: Verify the Setup

The `build.gradle.kts` file is already configured to:
- Load the keystore properties from `key.properties`
- Use the keystore for release builds
- Fall back to debug signing if the keystore file doesn't exist (for development)

## Step 4: Build a Release APK/AAB

To build a release app bundle (recommended for Play Store):

```bash
flutter build appbundle --release
```

The output will be at: `build/app/outputs/bundle/release/app-release.aab`

To build a release APK:

```bash
flutter build apk --release
```

The output will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Security Notes

- ✅ The `key.properties` and `*.jks` files are already in `.gitignore` and won't be committed to version control
- ⚠️ Never share your keystore file or passwords publicly
- ⚠️ Keep secure backups of your keystore file
- ⚠️ Consider using Google Play App Signing for additional security

## Google Play App Signing (Recommended)

Google Play App Signing allows Google to manage your app's signing key. This provides:
- Protection against key loss
- Automatic key management
- Additional security

You can enroll in Play App Signing when you upload your first app to the Play Console.

