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
