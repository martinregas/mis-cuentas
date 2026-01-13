
# Mis Cuentas MVP Setup Instructions

## Prerequisites
- Flutter SDK installed
- Xcode (for iOS)
- Android Studio (for Android)

## Running the App

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run on iOS Simulator**:
   ```bash
   open -a Simulator
   flutter run -d iphonesimulator
   ```

3. **Run on Android Emulator**:
   Start your emulator via Android Studio.
   ```bash
   flutter run
   ```

## Permissions & Configuration

### iOS (`ios/Runner/Info.plist`)
For file access and receiving shares, ensure the following keys are present (already configured by default usually, but for `receive_sharing_intent` check plugin docs if advanced config needed).
The app uses `file_picker` which handles basic permissions.

For sharing **OUT** (e.g. claims), no special permission needed.

For **receiving** files via Share Sheet:
You need to add a Runner configuration.
Add this to `Info.plist`:
```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>PDF Document</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.adobe.pdf</string>
        </array>
    </dict>
</array>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

### Android (`android/app/src/main/AndroidManifest.xml`)
For `receive_sharing_intent`:
Add the intent filter to your MainActivity `activity` block:
```xml
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="application/pdf" />
</intent-filter>
```

## Features
- **Import PDF**: Tap the FAB or "Import PDF" card on Home.
- **Transactions**: View parsed transactions.
- **Anomalies**: Automatically detected:
  - Duplicates (same merchant/amount within 48h).
  - High amounts (> 2.5x average).
  - Suspected subscriptions.
- **Local Data**: All data is stored locally in SQLite (`mis_cuentas.db`).
