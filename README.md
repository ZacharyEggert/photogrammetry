# Photogrammetry Utility

Mac app: folder of photos -> USDZ via RealityKit `PhotogrammetrySession`.

## Install

Grab `Photogrammetry.zip` from the
[latest release](https://github.com/ZacharyEggert/photogrammetry/releases/latest)
([all releases](https://github.com/ZacharyEggert/photogrammetry/releases)), unzip,
drag `Photogrammetry.app` (shows as **Photogrammetry Utility**) to `/Applications`. Signed and notarized, so it opens on
first launch — no Gatekeeper detour.

## How to use it

1. **Shoot the object.** One full circle around a single subject, 20+ overlapping
   photos, even lighting. A handful of catalog angles will fail.
2. **Point the app at the folder.** Drag the folder onto the orbit dial, or
   *Choose folder*. The dial shows how many photos it found and warns in red under 20.
3. **Pick a fidelity.** `preview` → `raw`. `medium` is a sane default; higher levels
   cost minutes and memory.
4. **Build model.** The dial fills as the solve advances.
5. **Collect the USDZ.** Saved next to your photos as `<folder>-<detail>.usdz`.
   *Reveal in Finder*, or click the dial.

Needs an Apple silicon Mac (Object Capture requirement).

## Building from source

- **Xcode:** `open Photogrammetry.xcodeproj` (real app target, signing, Run/Archive)
- **Xcode, SwiftPM-style:** `open Package.swift` also works
- **Terminal:** `swift run`
- **Bundle without an Xcode target:** `./build-app.sh` -> `Photogrammetry.app`

Both build paths share `Info.plist` and the app icon: `Resources/Appicon.icon`, edited in
Icon Composer and compiled by `actool`. `build-app.sh` reads the bundle id, icon name and
deployment target out of the xcodeproj so the two can't drift, which means it needs Xcode
installed even though it never invokes `xcodebuild`.

## Cutting a release

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
