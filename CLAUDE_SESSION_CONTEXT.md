# Context for a new Claude Code session on this machine

Paste this whole file as your first message to a fresh Claude Code session
in this repo's directory, then describe what happened when you ran through
`SETUP_NEW_MACHINE.md`.

---

## What this project is

A native iOS replacement for Fanimation's "fanSync" smart-fan app, built
because the user wants a native client instead of the official app. The
protocol was reverse-engineered from `github.com/rotinom/fansync` (a Python
client) and `tjbaker/homeassistant-fansync` (a Home Assistant integration).

**Protocol summary:** 100% cloud-based via Exosite's IoT platform. No local
LAN/BLE control for day-to-day use.
- REST login: `POST https://fanimation.apps.exosite.io/api:1/session` with
  `{email,password}` → `{id, token}` (long-lived JWT)
- WebSocket: `wss://fanimation.apps.exosite.io/api:1/phone`, login via
  `{id,request:"login",data:{token}}`
- Requests: `lst_device`, `get` (device), `set` (device + field→value dict),
  correlated by incrementing `id`
- Server pushes unsolicited `device_change` events with status diffs
- Field codes: H00=FAN_POWER, H01=FAN_MODE(0=Normal/1=Fresh Air),
  H02=FAN_PERCENT, H06=FAN_DIRECTION(0=Forward/1=Reverse), H0B=LIGHT_POWER,
  H0C=LIGHT_PERCENT, H0D=HOME_AWAY, H0E=ERROR_CODE
- TLS cert for exosite.io is a legitimate Amazon-issued cert (verified via
  openssl) — standard cert validation is used, no need to disable it.

## Critical constraint: target devices are iOS 12.5.8

The user has an **iPhone 6** and a **1st-generation iPad Air** (model
`iPad4,1`), both capped at iOS 12.5.8 — neither can be upgraded further.
This is the single most important constraint on this project. It ruled out
an entire first implementation attempt (SwiftUI) because SwiftUI, Combine,
async/await, URLSessionWebSocketTask, and SF Symbols all require iOS 13+.

## Two targets exist in this repo — use the right one

- **`FanSyncNative/`** (project.yml → `FanSyncNative.xcodeproj`): the
  original SwiftUI prototype, targets iOS 17.0. **Reference/throwaway only.**
  Do not extend it, do not copy its patterns into the real target.
- **`FanSyncNativeUIKit/`** (project-uikit.yml →
  `FanSyncNativeUIKit.xcodeproj`): **this is the real target.** Programmatic
  UIKit (no storyboards — user's explicit preference), iOS 12.0 deployment
  target, closure-based networking (no async/await), Starscream via SPM for
  WebSocket (URLSessionWebSocketTask requires iOS 13+), hand-drawn icons via
  `Views/IconFactory.swift` (SF Symbols require iOS 13+), `ObserverList`
  multicast closures in `App/Observable.swift` standing in for Combine.

Regenerate the UIKit project after adding/removing files:
```
xcodegen generate --spec project-uikit.yml
```

## UI reference

`OrigAppImages/*.png` — 11 screenshots of the official fanSync app that the
UI was built to match: device list (eggplant header, tabs for All + user
groups, device cards with pinwheel icon/toggle/slider/"More Controls"),
device detail bottom sheet (Breeze Mode + Fan Direction segmented pills,
Light/Home Away toggles, Settings/Schedules buttons, CLOSE bar), hamburger
side menu (Home/My Groups/Settings/Support + live account email + version),
My Groups (floor sections, drag handles, rename/move/delete action sheet),
app Settings (Connections pills, Account section), My Account, per-device
Settings (name/calibration/sharing/version/serial/delete), Create Schedule,
Schedule List, and the one-time WiFi-AP device-provisioning flow (out of
scope — provisioning a brand-new fan isn't needed for controlling
already-provisioned ones).

## Known inert/stubbed features (by design, not bugs)

These show matching UI but don't do anything real yet because no confirmed
wire format exists for them in the reverse-engineered protocol:
- Device rename (Save button in per-device Settings)
- Blade calibration, "Share Device", "Hide Light Dimmer" toggle
- Scheduling (Create Schedule / Schedule List) — entirely local UI, no
  schedule-related request type exists anywhere in the rotinom/fansync
  reference
- Amazon Echo / Google Home / IFTTT / SmartThings connection pills in
  Settings — these integrations are configured through Fanimation's own
  cloud account linking, not exposed by this protocol
- Account deletion — intentionally a no-op confirmation dialog; deleting a
  real account must never be attempted blind against an unofficial client
- Device provisioning (pairing a brand-new fan via its local WiFi AP) —
  explicitly out of scope per the user's "full replacement app" scope answer
  early in this project

If you're asked to wire any of these up for real, the right move is
re-deriving the wire format from a packet capture of the official app, not
guessing a request shape.

## Why we're on a second machine

The first machine (a 2013 iMac14,2 with an NVIDIA GeForce GTX 780M) turned
out to have broken Simulator GPU rendering — confirmed via screenshot:
pure black framebuffer on the iOS Simulator even on the plain Home Screen,
with no app running, surviving a full simulator erase + CoreSimulatorService
restart. This is unrelated to iOS 12 or to this app's code; it's a host-level
graphics problem specific to that aging hardware. See `SETUP_NEW_MACHINE.md`
in this repo for the full, gotcha-by-gotcha setup process on the new machine,
written specifically to avoid re-deriving the iOS-12 DeviceSupport trick and
other things we already solved once.

## Current status as of this handoff

- Code builds clean (0 errors, 0 warnings) via `xcodebuild` targeting an iOS
  Simulator on the old machine — but was never verified rendering correctly
  there due to the GPU issue above.
- Successfully installed and launched (process stayed alive, no crash) on
  an iPad Air 13" (M2) *simulator* on the old machine, but the screen was
  black due to the host GPU problem, not a code bug — confirmed because even
  the Simulator's plain Home Screen rendered black with no app running.
- Never yet confirmed working on an actual physical iOS 12.5.8 device
  (iPhone 6 or the real 1st-gen iPad Air) — pairing got as far as successful
  USB-level pairing (`usbmuxd` logged "Successfully paired") but `devicectl`/
  Xcode's higher-level device list never picked it up on the old machine,
  even after installing iOS 12 DeviceSupport files. Whether that was also a
  symptom of the same broken host, or a separate issue, is unresolved —
  worth testing cleanly on this new machine before assuming either way.

## What to do next

Work through `SETUP_NEW_MACHINE.md` in order. Report back what happens at
each step, especially device pairing (step 6) and what actually renders on
first launch (step 8) — black screen vs. the eggplant login screen vs.
anything else.
