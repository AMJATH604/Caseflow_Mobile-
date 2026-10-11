# Firebase iOS Setup & GoogleService-Info.plist Guide

This guide walks you through registering the iOS app in Firebase Console and getting the `GoogleService-Info.plist` file needed for Push Notifications (FCM), Crashlytics, and Analytics.

---

## Step 1: Open Your Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Select your existing **CaseFlow** project (the same one where your Android app is registered).

---

## Step 2: Add an iOS App to the Project

1. On the Project Overview page, click the **+ Add app** button (or click the iOS Apple icon).
2. Fill in the iOS app registration details:
   - **Apple bundle ID**: `com.caseflow.app` *(Must match exactly)*
   - **App nickname**: `CaseFlow iOS`
   - **App Store ID**: *(Leave blank for now, you can add it after publishing)*
3. Click **Register app**.

---

## Step 3: Download `GoogleService-Info.plist`

1. Click **Download GoogleService-Info.plist**.
2. Save the downloaded file to your computer.
3. Move the file into your CaseFlow project at the following path:
   ```bash
   apps/mobile/ios/Runner/GoogleService-Info.plist
   ```
4. You can skip the remaining steps in the Firebase wizard (SDK addition, initialization code) — the code in `AppDelegate.swift` and `Podfile` is already configured for you!

---

## Step 4: Configure Push Notifications (APNs) (When Enrolled in Apple Developer)

When you enroll in the Apple Developer Program ($99/yr):

1. Go to [Apple Developer Member Center](https://developer.apple.com/account/) > **Certificates, Identifiers & Profiles**.
2. Under **Keys**, click **+** to create an **APNs Authentication Key** (Apple Push Notifications service).
3. Name it (e.g. `CaseFlow APNs Key`), check the **Apple Push Notifications service (APNs)** checkbox, and click **Continue** > **Register**.
4. Download the `.p8` key file. Note your **Key ID** and your **Team ID**.
5. Go back to [Firebase Console](https://console.firebase.google.com/) > **Project Settings** (gear icon) > **Cloud Messaging** tab.
6. Scroll down to **Apple app configuration**.
7. Under **APNs Authentication Key**, click **Upload**:
   - Upload the `.p8` file.
   - Enter your **Key ID**.
   - Enter your **Team ID**.
8. Click **Upload**. Now Firebase can send push notifications directly to iOS devices!

---

## Step 5: For GitHub Actions CI/CD (Optional)

To enable automated iOS builds on GitHub Actions without committing the plist file to public git:

1. Base64 encode the `GoogleService-Info.plist`:
   ```bash
   base64 -i apps/mobile/ios/Runner/GoogleService-Info.plist | pbcopy
   ```
2. Go to your GitHub Repository > **Settings** > **Secrets and variables** > **Actions**.
3. Click **New repository secret**:
   - Name: `IOS_GOOGLE_SERVICES_PLIST`
   - Secret: Paste the clipboard contents.
4. Click **Add secret**.
