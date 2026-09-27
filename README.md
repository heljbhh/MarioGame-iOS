# MarioGame — iOS (SwiftUI + SpriteKit)

A native iOS Super Mario-style platformer. No third-party dependencies,
no image assets — everything is drawn with SpriteKit shapes.

- **Bundle ID:** `com.example.mariogame`
- **Deployment target:** iOS 16.0+
- **Orientation:** Landscape

## Gameplay

Run / jump with the on-screen buttons, stomp enemies, collect coins,
hit `?` blocks from below, avoid pits, and reach the flag at the end.

## Files

```
MarioGame-iOS/
├── codemagic.yaml                      # Codemagic workflow: ios-unsigned
├── MarioGame.xcodeproj/
│   ├── project.pbxproj                 # hand-written, plain-xcodebuild compatible
│   └── xcshareddata/xcschemes/MarioGame.xcscheme
└── MarioGame/
    ├── MarioGameApp.swift              # @main SwiftUI entry point
    ├── ContentView.swift               # SwiftUI view + SKView bridge + overlays
    ├── GameScene.swift                 # SpriteKit game: physics, level, enemies
    └── Info.plist
```

## Building in the cloud (free, no Mac needed)

1. Create a **GitHub** (or GitLab/Bitbucket) account if you don't have one.
2. Create a new repository and upload the contents of this folder
   (`codemagic.yaml` must be at the repo root).
3. Create a **Codemagic** account at https://codemagic.io (free tier:
   500 macOS build minutes/month) and connect the repository.
4. In Codemagic, start a new build and select the **ios-unsigned** workflow.
5. When the build finishes, download **MarioGame-unsigned.ipa**
   from the build artifacts.

## Installing on your iPhone (free Apple ID)

The IPA is **unsigned**. Install it with a sideloading tool on your computer:

- **AltStore** (https://altstore.io), **Sideloadly** (https://sideloadly.io),
  or **SideStore** — they sign the app with your own (free) Apple ID
  during installation.

Notes for the free-Apple-ID path:

- The signature expires after **7 days** — re-install (re-sign) weekly.
- Up to **3 sideloaded apps** at a time.
- A paid Apple Developer Program membership ($99/year) removes these limits
  (1-year signatures, TestFlight). To use it, switch the Codemagic workflow
  to a signed build with your certificate + provisioning profile.

## Opening the project on a Mac (optional)

Any Mac with Xcode 16+ opens `MarioGame.xcodeproj` directly —
press ⌘R to run on a simulator or device.
