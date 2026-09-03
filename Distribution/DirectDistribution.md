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

Archive the app:

```sh
xcodebuild archive \
    -scheme BizNoteMac \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath build/BizNoteMac.xcarchive
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
xcrun notarytool submit build/DeveloperID/BizNote.zip --keychain-profile <profile-name> --wait
xcrun stapler staple build/DeveloperID/BizNote.app
spctl -vvv --assess --type exec build/DeveloperID/BizNote.app
```

The machine exporting the app needs access to the Apple Developer team `8S2Y83DCGM`, a Developer ID Application certificate, and a notarytool keychain profile if using the manual notarization commands.
