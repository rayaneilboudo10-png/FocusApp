# FocusApp

A minimalist, OLED-black focus app for iPhone (tuned for the iPhone 13 Pro Max), written in Swift and SwiftUI. It targets iOS 17.0 or later.

It has three tabs:

- **Focus**: a timer, Hard Mode, Strict Focus Lock, the apps to block, and a daily limit.
- **Schedules**: recurring blocks such as "After School / Work, 4–7 PM, Mon–Fri".
- **Themes**: block-screen themes (Pure OLED, Midnight Slate, Deep Amber, Forest Night) and quotes (10 built in, plus your own).

## Project layout

```
project.yml                 XcodeGen spec (generates FocusApp.xcodeproj)
FocusApp/                   Main app
  Services/                 AppModel, SessionManager, ScreenTimeService,
                            NotificationService, LiveActivityService
  Views/                    Focus / Schedules / Themes, StrictLockView, BlockScreenView
  Design/                   Design tokens + reusable components
FocusWidgets/               Live Activity (Lock Screen countdown)
FocusShieldConfig/          ShieldConfigurationDataSource: themed block screen
FocusShieldAction/          ShieldActionDelegate: shield buttons
FocusActivityMonitor/       DeviceActivityMonitor: schedules + daily limits
Shared/Core/                Models, SharedStore (App Group defaults), themes
Shared/ScreenTime/          ManagedSettings / DeviceActivity helpers
Shared/LiveActivity/        ActivityKit attributes
Config/                     Free-account entitlements, export options
scripts/                    IPA build scripts
```

## How the features work

| Feature | With Screen Time (Family Controls entitlement) | Without it (free / sideload signing) |
|---|---|---|
| App blocking | `ManagedSettingsStore` shields chosen with `FamilyActivityPicker` | Strict Focus Lock: a full-screen countdown, plus "come back" notifications if you leave the app |
| Daily limits (15m / 30m / 1h / 2h) | `DeviceActivityEvent` threshold → shield | Not available (the UI is disabled and says why) |
| Schedules | `DeviceActivityMonitor` applies and lifts shields even when the app is closed | A start reminder notification; opening the app auto-starts the lock |
| Hard Mode | No stop/cancel/unblock buttons in the UI, the shield's secondary button is removed, and app removal is denied | No stop button; the lock persists across force-quits |
| Live Activity | Lock Screen countdown | Same |

**How Hard Mode stays persistent.** The session's end timestamp is saved to the App Group defaults and also mirrored to `UserDefaults.standard`. When the app relaunches it restores the lock until that timestamp. A Hard Mode schedule cannot be edited, disabled or deleted while it is active.

**Known limits.** iOS always lets you revoke the app's Screen Time access in Settings, and changing the device clock affects the timer. No third-party app can block either of these.

## Requirements

- A Mac with Xcode 15 or later (Xcode 16 recommended).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build & package (no paid developer account)

See the terminal instructions at the end of the chat, or:

```bash
brew install xcodegen
cd FocusApp
bash scripts/build_unsigned_ipa.sh com.yourname.focus      # → dist/FocusApp.ipa (unsigned)
```

You can also produce a locally signed IPA with a free Apple ID:

```bash
bash scripts/build_signed_ipa.sh <TEAM_ID> com.yourname.focus --free
```

Notes:

- A free Apple ID allows 10 App IDs per 7 days, and this app uses 5 (the app plus 4 extensions). Free signing expires after 7 days, so re-sign weekly.
- Sideloadly and AltStore may rename App Group IDs when they re-sign. If that happens, the app falls back to local storage. The app still works, but the Screen Time extensions can't read its settings. Those extensions only work with the Family Controls entitlement anyway.
- Family Controls requires a paid team. Development signing works immediately; App Store or TestFlight distribution needs Apple's approval of the entitlement.
