# Mac App Store status

Last checked: 2026-11-11

## Current status

- App Store Connect record: `Lumeth`, App ID `6833060702`
- Bundle ID: `com.sansi.lumeth`
- Version: `1.1`, build `8`
- Review state: `WAITING_FOR_REVIEW`
- Price: free in 174 App Store territories; mainland China is excluded
- Age rating: 4+
- App privacy: no data collected
- Primary category: Utilities
- Screenshots: two 2560×1600 desktop screenshots uploaded
- Distribution certificate and Mac App Store profile are valid through
  2027-11-10.

## GitHub Actions release

`.github/workflows/appstore.yml` builds, signs, validates and optionally uploads
the Mac App Store package. It is triggered manually or by a `v*` tag.

`.github/workflows/build.yml` runs a release Swift build on source changes and
uses the supported `macos-15-intel` runner.

Repository secrets:

- `APPLE_DISTRIBUTION_P12`
- `APPLE_DISTRIBUTION_P12_PASSWORD`
- `MAC_INSTALLER_P12`
- `MAC_INSTALLER_P12_PASSWORD`
- `MAC_APP_STORE_PROFILE`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8`

All certificate and key values are stored as base64 text in encrypted GitHub
Actions secrets; no signing material is committed to the repository.

Run from the repository Actions tab, or:

```bash
gh workflow run appstore.yml -f upload=true -f version=1.1
```

## Steps to publish

1. Sign in to Xcode with the Apple ID that belongs to team `SV2LZPC92A`
   (Xcode → Settings → Accounts).
2. In Apple Developer Certificates, renew/create:
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
     -exportOptionsPlist scripts/ExportOptions.plist \
     -allowProvisioningUpdates
   ```

   Or run the helper after the certificates are installed:

   ```bash
   ./scripts/build-appstore.sh
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
