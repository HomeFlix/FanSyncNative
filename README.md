# FanSyncNative

A native iOS replacement for Fanimation's official **fanSync WiFi** app, built so that old iOS hardware can keep working as dedicated smart-fan remotes instead of ending up in a drawer.

## Why this exists

Fanimation's official fanSync WiFi app only installs on relatively recent versions of iOS. That leaves a pile of perfectly good spare hardware — older iPhones and iPads — unable to run it, even though they'd otherwise make great dedicated, always-on remotes mounted near a light switch or sitting on a nightstand.

This project is a from-scratch native iOS app that speaks the same cloud protocol as the official app, targeting **iOS 12.0** so it installs and runs on devices the official app has left behind (confirmed working on an iPhone 6 and a 1st-generation iPad Air, both capped at iOS 12.5.8).

It was built with the help of AI-assisted development and a community-maintained reference of Fanimation's cloud protocol (the [`rotinom/fansync`](https://github.com/rotinom/fansync) Python client and related Home Assistant integration work), cross-checked against live packet captures of the real app to confirm exact request/response shapes before implementing each feature.

## What it does

- Logs in with the same Fanimation/Exosite cloud account as the official app
- Connects over the same WebSocket control channel and controls real fans/lights in real time
- Shows and edits the same device groups ("First Floor," "Second Floor," etc.) as the official app — groups are stored server-side, not just locally
- Matches the official app's visual design (login screen, device cards, icons, colors) where screenshots and captures were available to work from

## Why iOS 12

The target hardware (iPhone 6, iPad Air 1st gen) caps out at iOS 12.5.8. That rules out SwiftUI, Combine, Swift concurrency (`async`/`await`), `URLSessionWebSocketTask`, and SF Symbols — all of which have an iOS 13+ floor, even when "backward deploying." The app is written in plain UIKit with programmatic Auto Layout (no storyboards, except the one iOS 12 still requires for the launch screen) and closure-based networking throughout.

WebSocket support comes from [Starscream](https://github.com/daltoniam/Starscream), since `URLSessionWebSocketTask` isn't available on iOS 12.

## Project structure

- `FanSyncNativeUIKit/` — the app target (iOS 12.0)
- `project-uikit.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec for the target; the checked-in `.xcodeproj` is generated from this
- `OrigAppImages/` — local-only reference material (screenshots, packet captures) used during development; gitignored, since it contains real account tokens

## Building

```sh
xcodegen generate --spec project-uikit.yml
```

This regenerates `FanSyncNativeUIKit.xcodeproj`. Note: regenerating resets the project's code-signing Team selection — open the project in Xcode afterward and reselect your Apple ID under **Signing & Capabilities** before building.

```sh
xcodebuild -project FanSyncNativeUIKit.xcodeproj -scheme FanSyncNativeUIKit \
  -destination 'platform=iOS,name=<your device name>' build
```

Deploying to an iOS 12 device reliably works through Xcode's own **Run** (⌘R) command rather than `xcodebuild ... install`, which has been unreliable against this vintage of hardware/pairing.

## Status

Core functionality — login, device control, groups — is working end-to-end against a real account and real hardware. Some secondary screens (device rename, blade calibration, scheduling) exist as UI-only stubs, since no confirmed wire format for those features has been captured yet.

This is a personal-use project built for one household's hardware, not a general-purpose or officially supported client.
