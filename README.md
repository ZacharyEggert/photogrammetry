# Photogrammetry

Mac app: folder of photos -> USDZ via RealityKit `PhotogrammetrySession`.

- **Xcode:** `open Photogrammetry.xcodeproj` (real app target, signing, Run/Archive)
- **Xcode, SwiftPM-style:** `open Package.swift` also works
- **Terminal:** `swift run`
- **Bundle without an Xcode target:** `./build-app.sh` -> `Photogrammetry.app`

Both build paths share `Info.plist` and the app icon: `Resources/Appicon.icon`, edited in
Icon Composer and compiled by `actool`. `build-app.sh` reads the bundle id, icon name and
deployment target out of the xcodeproj so the two can't drift, which means it needs Xcode
installed even though it never invokes `xcodebuild`.

Input needs dense orbital coverage — 20+ overlapping shots. A handful of catalog angles will fail.

## Releases

Push a `vMAJOR[.MINOR[.PATCH]]` tag (integers only, no leading zeros) and
`.github/workflows/release.yml` builds, Developer ID signs, notarizes, staples and
publishes `Photogrammetry.zip`. The tag is stamped into `MARKETING_VERSION`, which
`Info.plist` reads, so the version lives only in the tag.

Repository secrets it needs:

| Secret | What it is |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Developer ID Application cert + key, exported as .p12, `base64 -i cert.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | Password set during that .p12 export |
| `NOTARY_API_KEY_P8_BASE64` | App Store Connect API key .p8, `base64 -i key.p8` |
| `NOTARY_API_KEY_ID` | That key's Key ID |
| `NOTARY_API_ISSUER_ID` | Issuer ID from App Store Connect ▸ Users and Access ▸ Integrations |

Local `./build-app.sh` signs ad hoc and needs no certificate. Set `CODESIGN_IDENTITY`
to sign with a real one.
