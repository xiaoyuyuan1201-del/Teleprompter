# Teleprompter MVP for iOS 26

A native SwiftUI teleprompter project for Xcode 26. The interface uses standard iOS navigation with a compact utility-first visual system. Liquid Glass is limited to system navigation and camera controls, while content panels use restrained 8-12 pt corner radii. Creator Violet (`#6C5CE7`) remains the accent color.

## Open in Xcode

1. Use Xcode 26 or later.
2. Open `Teleprompter.xcodeproj`.
3. Select the Teleprompter target.
4. In Signing & Capabilities, select your Apple Developer Team.
5. Replace `com.example.teleprompter` with your Bundle Identifier.
6. Run on an iPhone with iOS 26 or later.

Camera recording, Apple Intelligence, Photos access, and StoreKit purchases should be tested on a physical device.

## Included product flow

- Nine-step onboarding with a fixed header, progress bar, and guided setup
- Transparent Pro trial paywall
- Three-tab main navigation: Home, Videos, and Mine
- Script library and multiple draft workflow
- Script editor with paste, TXT import, PDF import, and autosave
- AI Polish with Grammar, Natural, and Concise modes
- Before/after AI comparison and explicit apply action
- Full-screen camera teleprompter
- Pre-record camera, microphone, and storage checks
- 1080p front and rear camera recording
- Pause and resume recording using merged local video segments
- Silent in-recording warning banners
- Post-record video and audio verification
- Playback, Save to Photos, Retake, and system Share Sheet
- Automatic in-app video library with playback, rename, share, and delete
- Prompting preferences, Pro status, restore purchase, support, and app information moved into Mine

## Script and file management

- Atomic JSON persistence in Application Support, with legacy UserDefaults migration
- Automatic draft saving after edits
- Draft recovery after the app is terminated
- Multiple saved drafts
- Rename, duplicate, favorite, delete, and edit
- Sort by newest, oldest, or title
- Free limit of three scripts; Pro unlocks unlimited scripts
- TXT and PDF text import through the system file picker

## Prompt controls

- Fixed-speed scrolling
- Finish-on-time scrolling based on a target duration
- Adjustable font size
- Adjustable side margins
- Near-lens reading position
- Mirror mode
- Optional 3-second countdown
- Manual script dragging remains available while automatic scrolling is active

## AI Polish

AI Polish uses the iOS 26 Foundation Models framework and the on-device Apple Intelligence model. It requires:

- An Apple Intelligence compatible device
- Apple Intelligence enabled in Settings
- A supported input language
- An active Teleprompter Pro entitlement

If the model is unavailable, the app shows a clear message and leaves the original script unchanged.

## Configure In-App Purchases

Open:

`Teleprompter/Services/PurchaseManager.swift`

Replace these placeholder product identifiers:

```swift
static let monthlyID = "com.yourcompany.teleprompter.pro.monthly"
static let yearlyID = "com.yourcompany.teleprompter.pro.yearly"
```

Create matching auto-renewable subscriptions in App Store Connect. Configure an introductory trial there if the paywall should offer the displayed 3-day free trial. StoreKit supplies the real localized renewal price after configuration.

## Paywall disclosure

The paywall visibly includes:

- A close button
- Restore Purchase in the navigation bar and purchase area
- Trial duration
- Estimated trial end date
- Renewal amount and billing period
- Auto-renewal and cancellation wording
- A reminder that final eligibility and terms are confirmed by the App Store

## Before release

- Replace the Bundle Identifier and IAP product IDs.
- Configure the introductory trial in App Store Connect.
- Add real Terms of Use and Privacy Policy destinations.
- Replace the support email address in MineView.swift.
- Test PDF extraction with representative files.
- Test AI Polish across supported languages and device states.
- Test camera switching, pause/resume merging, interruption handling, storage warnings, Photos saving, sharing, and purchases on physical devices.


## Latest layout update

- Restored the large Quick Start hero panel on Home.
- Reduced the hero corner radius to 12pt for a more tool-like appearance.
- Standardized primary screen horizontal margins to 20pt.
