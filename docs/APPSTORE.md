# Mac App Store status

Last checked: 2026-11-10

## What already works

- The app builds with Xcode and can be archived.
- The archive is universal (`arm64` + `x86_64`).
- The archive is signed with the sandbox entitlement
  `com.apple.security.app-sandbox`.
- `PrivacyInfo.xcprivacy` is embedded for UserDefaults and system boot time.
- A local sandbox smoke test still reported CPU, memory, network, disk, GPU,
  battery and 21 HID temperature sensors.
- The Xcode archive succeeded with Apple Development signing.

## Current blocker

`xcodebuild -exportArchive` for App Store Connect stops with:

```text
No Accounts
No signing certificate "Mac Installer Distribution" found
No profiles for 'com.sansi.lumeth' were found
```

The machine has an Apple Development identity and a Developer ID identity, but
no Apple Distribution / Mac Installer Distribution identity, no Mac App Store
provisioning profile, and no App Store Connect account session or API key.

These are account-side operations and cannot be completed without access to
the Apple Developer / App Store Connect account.

## Steps to publish

1. Sign in to Xcode with the Apple ID that belongs to team `SV2LZPC92A`
   (Xcode → Settings → Accounts).
2. In Apple Developer Certificates, create:
   - `Apple Distribution` (Mac App Store)
   - `Mac Installer Distribution`
3. Register the App ID `com.sansi.lumeth` and create a **Mac App Store**
   provisioning profile for it.
4. In App Store Connect, create a macOS app record:
   - Name: `Lumeth`
   - SKU: `lumeth-macos`
   - Bundle ID: `com.sansi.lumeth`
   - Category: Utilities
5. Fill in the metadata, privacy policy URL, support URL, age rating and
   screenshots. Required macOS screenshot sizes include 1280×800,
   1440×900, 2560×1600 and 2880×1800.
6. Re-export:

   ```bash
   xcodebuild -exportArchive \
     -archivePath build/Lumeth.xcarchive \
     -exportPath build/export \
     -exportOptionsPlist build/ExportOptions.plist \
     -allowProvisioningUpdates
   ```

7. Upload the exported package with Transporter, or with an App Store Connect
   API key:

   ```bash
   xcrun altool --upload-app \
     -f build/export/Lumeth.pkg \
     -t macos \
     --apiKey "$ASC_KEY_ID" \
     --apiIssuer "$ASC_ISSUER_ID"
   ```

## App Review notes

- Lumeth is an `LSUIElement` menu-bar/agent app with no Dock icon.
- It reads system counters through public, read-only APIs:
  `host_statistics64`, `host_processor_info`, `getifaddrs`, `statfs`,
  IOKit GPU statistics and `IOHIDEventSystemClient`.
- It does not request Accessibility, Input Monitoring, Full Disk Access or
  root privileges.
- It does not install a background daemon and does not connect to the network.
- Fan control is not implemented; the UI explicitly explains that it needs a
  privileged SMC helper.

## App Sandbox verification

The local sandbox build was created with:

```bash
codesign --force --options runtime \
  --entitlements Resources/Lumeth.entitlements \
  --sign - build/Lumeth.app
```

The dump run reported 21 sensors and available GPU/battery/network data. This
is a local compatibility check, not a substitute for App Store review.
