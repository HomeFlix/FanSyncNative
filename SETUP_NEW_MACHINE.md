# FanSyncNative — Setup on a New Mac for iOS 12.5.8 Device Testing

> ⚠️ **DO NOT use this on a Mac running macOS Tahoe (26.x).** Tahoe requires
> Xcode 26+, and Xcode 26+ **cannot connect to or deploy on any device
> running iOS below 15.0** — a hard limitation Apple built into the tool, not
> fixable by anything in this document. This was tried and failed. Only
> follow this guide on a Mac running **macOS Sonoma or Sequoia** (i.e. one
> that can install Xcode 16.x). See `CLAUDE_SESSION_CONTEXT.md` for the full
> story — the recommended path is actually fixing the *original* iMac
> (Sequoia + Xcode 16, where device pairing was already working), not moving
> to a third machine.

**Objective:** deploy and test `FanSyncNativeUIKit` on a physical iPhone 6 and a
1st-generation iPad Air, both running iOS 12.5.8. Every step below is written
specifically to avoid the iOS-12-compatibility gotchas already hit once.

Read this whole document before running anything — the order matters.

---

## 0. Known gotchas this doc exists to prevent

These are not hypothetical — we hit every one of these on the first machine:

1. **Xcode 16 ships zero DeviceSupport files below iOS 15.0.** Without extra
   files, Xcode physically cannot talk to an iOS 12 device over USB, even
   once it's trusted/paired. Section 3 below fixes this *before* you ever
   plug in a device, so you don't waste time thinking a trust-prompt retry
   will fix a missing-files problem.
2. **async/await, Combine's `@Published`/`ObservableObject`, SwiftUI,
   `URLSessionWebSocketTask`, and SF Symbols (`UIImage(systemName:)`) all
   require iOS 13+.** None of them appear in `FanSyncNativeUIKit` — only in
   the old `FanSyncNative/` SwiftUI folder, which is reference-only and is
   **not** the target. Do not "fix" FanSyncNativeUIKit by copying patterns
   from FanSyncNative — that'll reintroduce iOS 13+ dependencies.
3. **No SceneDelegate.** iOS 12 predates it. `AppDelegate.swift` creates the
   `UIWindow` directly. There's a `#available(iOS 13.0, *)` branch in there
   for when the *same* build runs on a modern Simulator (which auto-creates a
   scene behind the scenes) — don't remove that branch, and don't assume it's
   dead code.
4. **`UIActivityIndicatorView(style: .large/.medium)` requires iOS 13+** — we
   use `.whiteLarge`/`.white`, the iOS 12-safe names.
5. Current Xcode versions require a **free Apple ID signed in under
   Xcode → Settings → Accounts** to code-sign a build for a physical device,
   even for personal/non-App-Store builds.

---

## 1. Install Xcode 16

Homebrew **cannot** install Xcode itself (Apple doesn't allow redistributing
it). Use `xcodes`, a CLI/GUI tool for managing Xcode versions:

```
brew install --cask xcodes-app
open -a Xcodes
```

In the Xcodes app: sign in with your Apple ID, find **Xcode 16** (any 16.x
point release) in the list, click Install. This is a large download
(~10-15GB) — let it finish fully before continuing.

Once installed, set it as the active developer directory (this needs your
Mac password interactively, so run it in a real terminal, not through an
automated tool):

```
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -version
```

Confirm the version printed is 16.x before moving on.

### Also install the iOS Simulator runtime (optional but recommended)

Even though the real target is physical devices, having a working simulator
is useful for quick iteration. In Xcode: **Settings → Platforms** → find iOS
and click the download/GET button. (We never got this working for *iOS 12*
testing on the old machine — the Simulator itself doesn't let you run truly
old iOS versions since Xcode 14 dropped support for runtime images below
iOS 15 — so the simulator is only useful for a general build/UI sanity check
on a modern simulated device, not for validating iOS 12 behavior. Physical
devices are the only real iOS 12 test.)

---

## 2. Install supporting tools

```
brew install git gh xcodegen
gh auth login
```

For `gh auth login`, choose: GitHub.com → HTTPS → "Authenticate Git with your
GitHub credentials? Yes" → "Login with a web browser". Follow the prompts; it
opens your browser for a one-time code.

Verify:
```
gh auth status
```
Should show `Logged in to github.com account HomeFlix`.

---

## 3. Install iOS 12 DeviceSupport files — do this BEFORE plugging in any device

This is the step that's easy to skip and then burn an hour debugging a
"device not showing up" problem that's actually just missing files. Do it now.

```
mkdir -p ~/Development
cd ~/Development
git clone --depth 1 --filter=blob:none --sparse https://github.com/iGhibli/iOS-DeviceSupport.git devicesupport-ref
cd devicesupport-ref
git sparse-checkout set "DeviceSupport/12.4.zip" "DeviceSupport/12.4 (16G73).zip"
```

Extract the real retail build (not the beta one):

```
unzip -q "DeviceSupport/12.4 (16G73).zip" -d /tmp/ds-extract
```

Copy it into Xcode's DeviceSupport directory as `12.4` (this needs sudo —
run interactively):

```
sudo cp -R "/tmp/ds-extract/12.4 (16G73)" "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/12.4"
```

Verify:
```
ls "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport"
```
Should list `12.4` alongside whatever Xcode bundled natively (15.0, 15.2, etc).

**Why 12.4 and not 12.5.8 exactly:** no repo has an exact 12.5.8 entry;
Apple doesn't change the on-disk debug-symbol format within a major OS
version, so the nearest available 12.x file set (12.4) works for any 12.x
device. This is the same approach already validated conceptually on the old
machine — the file layer worked; what ultimately blocked us on the iMac was
unrelated broken GPU rendering in the Simulator, not this step.

---

## 4. Clone the project

```
cd ~/Development
git clone https://github.com/HomeFlix/FanSyncNative.git
cd FanSyncNative
```

Regenerate the Xcode project from the checked-in source (the `.xcodeproj` is
also committed, but regenerating confirms xcodegen + the yml are in sync on
this machine):

```
xcodegen generate --spec project-uikit.yml
```

This creates `FanSyncNativeUIKit.xcodeproj`. **Use this one** — not
`FanSyncNative.xcodeproj`, which is the old SwiftUI iOS-17 reference project
and will not run on iOS 12 devices at all.

---

## 5. Open in Xcode and sign in your Apple ID

```
open FanSyncNativeUIKit.xcodeproj
```

In Xcode: **Settings (⌘,) → Accounts → "+"** → sign in with any Apple ID
(a free one is fine, no paid developer account needed for local device
testing). Then select the `FanSyncNativeUIKit` project in the navigator →
target `FanSyncNativeUIKit` → **Signing & Capabilities** tab → set **Team**
to your Apple ID. Xcode will auto-manage a free provisioning profile.

---

## 6. Connect the iPhone 6 / iPad Air

1. Plug in via USB (use a known-good data cable — not a charge-only one).
2. **Unlock the device** before/at the moment you plug it in. On the
   device's screen, tap **Trust This Computer?** and enter the device
   passcode if asked. (If no prompt appears: unplug, unlock the device
   first, then replug.)
3. Verify the Mac sees it:
   ```
   xcrun devicectl list devices
   ```
   If this shows "No devices found" after trust is granted, check:
   - `system_profiler SPUSBDataType | grep -A8 -i iphone` (or `ipad`) — does
     the device show up at the raw USB level at all? If not, it's a cable/
     port issue, not software.
   - Logs for the actual pairing attempt:
     ```
     /usr/bin/log show --last 2m --predicate 'process == "usbmuxd"'
     ```
     Look for `Successfully paired` (good) vs. `kAMDPasswordProtectedError`
     (device was locked at the exact pairing moment — unlock and retry) vs.
     anything about `DeviceSupport`/`downloadSymbols` failing (means step 3
     above didn't take — re-check the DeviceSupport folder).

4. In Xcode's toolbar device picker (next to the scheme selector), select
   the physical device by name (not a simulator).

---

## 7. Build and run

Either click the Run button (▶) in Xcode, or from the command line:

```
xcodebuild -project FanSyncNativeUIKit.xcodeproj -scheme FanSyncNativeUIKit \
  -destination 'platform=iOS,name=<device name as shown in devicectl>' build
```

First run on a new device may prompt you, **on the device itself**, to go to
**Settings → General → VPN & Device Management** and explicitly trust the
developer certificate before the app will launch. This is a device-side
step Xcode cannot do for you.

---

## 8. What "success" looks like

- App installs without a "could not find DeviceSupport" or pairing error.
- App launches to the eggplant-colored login screen (matches the screenshots
  in `OrigAppImages/`), not a black screen.
- Text fields, toggle, and Log In button are visible and tappable.

If you get a **black screen with no crash** (app process stays alive, no
crash log), that was the exact symptom of the broken-GPU iMac — on this
machine it should not happen on a real device (it was a Simulator-only
rendering problem there), but if it somehow does, check
`AppDelegate.swift`'s window-scene handling first; that's the one piece of
code that differs between "normal" and "degraded host" launches.

---

## 9. Reporting back

When resuming work in a new Claude Code session on this machine, paste this
whole file's path and say what happened at each numbered step, especially
step 6 (pairing) and step 8 (what rendered). That's enough context to pick
up without re-deriving everything above.
