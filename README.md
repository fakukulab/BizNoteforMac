# BizNote for Mac

BizNote for Mac is a macOS SwiftUI app that syncs notes and business cards with the iOS BizNote app through the same CloudKit container.

- CloudKit container: `iCloud.com.fakuku.biznote`
- Bundle ID: `com.fakuku.biznote.mac`
- Team ID: `8S2Y83DCGM`
- Minimum macOS: 15.0
- Xcode: 27+

## Project

- App source: `BizNoteMac/`
- Xcode project: `BizNoteMac.xcodeproj`
- XcodeGen config: `project.yml`
- App development notes: `docs/APP_README.md`
- App Store submission notes: `docs/AppStoreConnectSubmission.md`
- Direct distribution notes: `Distribution/DirectDistribution.md`

## Build

```sh
xcodebuild -project BizNoteMac.xcodeproj \
    -scheme BizNoteMac \
    -destination 'platform=macOS' \
    -configuration Debug \
    build
```

CloudKit features require signing with the Apple Developer team listed above.

## Direct Distribution

The app includes a Developer ID export options file for distribution outside the Mac App Store:

```text
Distribution/ExportOptions-DeveloperID.plist
```

See `Distribution/DirectDistribution.md` for the archive, export, notarization, and Gatekeeper validation workflow.

## Website

GitHub Pages files are kept in this repository for App Store Connect metadata:

- Marketing URL: `https://fakukulab.github.io/BizNoteforMac/`
- Support URL: `https://fakukulab.github.io/BizNoteforMac/support.html`
- Privacy Policy URL: `https://fakukulab.github.io/BizNoteforMac/privacy.html`
