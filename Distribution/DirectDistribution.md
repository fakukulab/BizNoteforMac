# Direct Distribution

BizNote can be distributed outside the Mac App Store as a Developer ID signed and notarized macOS app.

## Current project state

- App Sandbox is enabled.
- Hardened Runtime is enabled.
- The app uses the existing entitlements file at `BizNoteMac/BizNoteMac.entitlements`.
- The export options file for direct distribution is `Distribution/ExportOptions-DeveloperID.plist`.

## Xcode Organizer workflow

1. Select the `BizNoteMac` scheme.
2. Choose `Product > Archive`.
3. Open `Window > Organizer` and select the archive.
4. Click `Distribute App`.
5. Choose `Direct Distribution` or `Developer ID`, depending on the Xcode wording.
6. Choose upload/notarization when prompted.
7. After notarization finishes, export the archive again so the stapled ticket is included.

## Command-line export

Before exporting from the command line, verify that this Mac has a Developer ID signing identity:

```sh
security find-identity -v -p codesigning | grep 'Developer ID Application'
```

For manual notarization, also create a notarytool profile once:

```sh
xcrun notarytool store-credentials BizNoteMac \
    --apple-id kimjyun@me.com \
    --team-id 8S2Y83DCGM \
    --keychain ~/Library/Keychains/login.keychain-db \
    --validate
```

Archive the app:

```sh
xcodebuild archive \
    -project BizNoteMac.xcodeproj \
    -scheme BizNoteMac \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath build/BizNoteMac.xcarchive \
    -allowProvisioningUpdates
```

Export a Developer ID signed app from the archive:

```sh
xcodebuild -exportArchive \
    -archivePath build/BizNoteMac.xcarchive \
    -exportPath build/DeveloperID \
    -exportOptionsPlist Distribution/ExportOptions-DeveloperID.plist \
    -allowProvisioningUpdates
```

If you notarize manually, compress the exported app before upload:

```sh
ditto -c -k --keepParent build/DeveloperID/BizNote.app build/DeveloperID/BizNote.zip
xcrun notarytool submit build/DeveloperID/BizNote.zip \
    --keychain-profile BizNoteMac \
    --keychain ~/Library/Keychains/login.keychain-db \
    --wait
xcrun stapler staple build/DeveloperID/BizNote.app
spctl -vvv --assess --type exec build/DeveloperID/BizNote.app
```

The machine exporting the app needs access to the Apple Developer team `8S2Y83DCGM`, a Developer ID Application certificate, and a notarytool keychain profile if using the manual notarization commands.

## 2026-09-03 local verification

- Xcode IDE build succeeded through the Xcode build tool.
- Command-line `xcodebuild archive` is currently blocked on this Mac by Xcode 27 beta macro server errors such as `SwiftDataMacros.PersistentModelMacro` and `SwiftUIMacros.StateMacro` reporting `swift-plugin-server produced malformed response`.
- `security find-identity -v -p codesigning` lists `Developer ID Application: Jyun Kim (8S2Y83DCGM)`.
- `xcrun notarytool history --keychain-profile BizNoteMac --keychain ~/Library/Keychains/login.keychain-db` succeeds and currently reports `No submission history`.

Resolve the Xcode beta/toolchain issue before producing the first public direct-distribution build.
