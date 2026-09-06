---
description: Build and deploy the mobile APK for Android
---

## Steps to Build Mobile APK

// turbo-all

1. Build the web assets:
```
npm run build
```

2. Run Capacitor copy (for Cordova stubs and native config):
```
npx cap copy android
```

3. Manually copy dist files to Android assets (workaround for OneDrive path issue):
```
Copy-Item -Path dist/* -Destination android/app/src/main/assets/public/ -Recurse -Force
```

4. Verify files are in place:
```
Get-ChildItem -Path android/app/src/main/assets/public -Name
```
Expected output should include: `index.html`, `assets/`, `favicon.ico`, etc.

5. Open in Android Studio:
```
npx cap open android
```

6. In Android Studio:
   - **Build > Clean Project**
   - **Build > Build Bundle(s) / APK(s) > Build APK(s)**
   - Click **locate** when prompted to find the APK
