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

Publishing a GitHub Release is the production trigger. Create a Release from a
tag such as `v1.2.0` and publish it. `.github/workflows/appstore.yml` then:

1. Resolves the App Store version from the tag.
2. Creates the new App Store version when needed.
3. Copies the previous version's English listing, App Review contact and
   release notes.
4. Uploads the repository screenshots when the new version has none.
5. Builds, signs and validates the universal Mac App Store package.
6. Uploads the package to App Store Connect.
7. Waits for build processing, attaches it to the version, and submits the
   version for App Review.

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
Actions secrets; no signing material is committed to the repository. App Store
listing text, screenshots and review contact details are not stored in secrets.

The workflow can also be started manually:

```bash
gh workflow run appstore.yml \
  -f version=1.2.0 \
  -f upload=true \
  -f submit_for_review=true \
  -f release_notes="What changed in this release"
```

Before publishing a release, update `docs/screenshot-overview-2560x1600.png`
and `docs/screenshot-cpu-2560x1600.png` if the UI changed. A release only
submits a new version automatically after the previous version has left review;
concurrent App Review submissions are rejected by Apple.

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
