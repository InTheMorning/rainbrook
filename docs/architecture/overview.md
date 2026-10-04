# CitizenRadio architecture

## Purpose

CitizenRadio plays one saved Icecast stream after a user action or a Shortcuts automation.
The user enters the URL in the app.
The source code contains no station URL.

## Data flow

```text
Car Bluetooth connection
  -> Shortcuts automation
  -> PlayRadioIntent
  -> RadioPlayer
  -> AVPlayer
  -> Current iOS audio output

SettingsView -> StreamStore -> UserDefaults
PlayRadioIntent -> StreamStore -> Saved stream URL
```

Shortcuts owns the Bluetooth trigger.
CitizenRadio does not scan for Bluetooth devices or request location access.
Apple supports a trigger for a selected Bluetooth device.
See [Apple's setting triggers](https://support.apple.com/guide/shortcuts/setting-triggers-apde31e9638b/ios).

## Components

| Component | Responsibility |
| --- | --- |
| `CitizenRadioApp` | Creates the SwiftUI scene. |
| `PlayerView` | Shows the artwork placeholder, status, Play or Stop, and the AirPlay button. |
| `SettingsView` | Edits and saves the stream URL in a sheet. |
| `PlaybackState` | Names the playback states and their status titles. |
| `ChimeSetting` | Stores the chime setting and selects the states that play the chime. |
| `PlayerScreenModel` | Selects the status text and the Play or Stop control for the player screen. |
| `StreamSettingsDraft` | Enables Save for a changed, non-empty URL or a changed chime setting. |
| `StreamAddress` | Validates the URL before storage or playback. |
| `StreamStore` | Reads and writes the saved URL. |
| `PlaybackRequest` | Controls if playback can continue after an interruption. |
| `RadioURLAction` | Accepts the Play and Stop control URLs. |
| `RadioPlayer` | Owns AVPlayer, the audio session, observers, and remote controls. |
| `PlayRadioIntent` | Starts the saved stream and waits for playback. |
| `StopRadioIntent` | Stops playback and cancels pending connection work. |
| `RadioShortcuts` | Makes the Play and Stop actions discoverable. |

The Xcode target compiles all thirteen Swift source files into the app.
The Swift package exposes the `CitizenRadio` app library and an internal `CitizenRadioCore` target.
The app target depends on the core target.
Its four UI and playback files use an iOS compilation condition so host tests do not need Apple frameworks.
The app has one player instance on the main actor.
Its URL actions and App Intents use that same instance.

## xtool packaging

`xtool.yml` selects the `CitizenRadio` library product for the app.
xtool supplies the executable entry point from the app's SwiftUI `@main` declaration.
The package uses Swift 5 language mode and an iOS 17 deployment target.
The core tests remain available through `swift test`.

`Configuration/xtool-info.plist` supplies literal runtime settings.
It contains no Xcode build variables.
xtool supplies the bundle identifier, executable name, and minimum OS version from its configuration and the package.
The overrides retain background audio, HTTP media access, local network access text, and iPhone orientations.
The icon uses `iconPath`. The privacy manifest, `forcdchime.wav` and the App Intents metadata use the root `resources` list.
See xtool's [configuration schema](https://github.com/xtool-org/xtool/blob/main/Sources/PackLib/PackSchema.swift) and [plist assembly](https://github.com/xtool-org/xtool/blob/main/Sources/PackLib/Planner.swift).

The Swift package compiles `RadioIntents.swift` like the Xcode target.
xtool does not extract App Intents metadata ([issue 145](https://github.com/xtool-org/xtool/issues/145)).
Its [packer](https://github.com/xtool-org/xtool/blob/main/Sources/PackLib/Packer.swift) has no metadata stage.
`Configuration/AppIntents/Metadata.appintents` holds the metadata that Xcode generates, made by `scripts/generate-app-intents-metadata.sh`.
It names the intent types by module (`CitizenRadio`) and mangled type name, which match in both builds.
xtool copies this directory to the app bundle root before it signs the app, so `xtool dev` signs one time.
Do not add files to an app that xtool signed, and do not install a signed app again with `xtool install`.
xtool signs again and adds a second `XTL-<team>.` prefix to the bundle ID.
See [ADR 0003](../adr/0003-committed-app-intents-metadata.md).

As a fallback, Shortcuts can use **Open URLs** with `citizenradio://play` or `citizenradio://stop`.
These actions open the app and can require device unlocking.
They do not provide the background launch behavior of `AudioPlaybackIntent`.
The URL handler uses only the saved stream and rejects additional URL parameters.
It cannot change the stream setting from an external URL.
Each build registers the same scheme and supports these URL actions.

## Playback rules

The two intents adopt `AudioPlaybackIntent` and set `openAppWhenRun` to `false`.
Apple defines this protocol for intents that change audio playback.
See [AudioPlaybackIntent](https://developer.apple.com/documentation/appintents/audioplaybackintent).

The audio session uses the playback category.
The app declares the `audio` background mode.
Apple documents this mode for audio content that continues in the background.
See [background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes).

- A repeated Play request keeps an active connection to the same stream.
- If the chime setting is on, `forcdchime.wav` plays in a loop while the state is `connecting`. It stops at all other states.
- The Play intent returns success after AVPlayer reports playback.
- Invalid settings and connection failures return an error to Shortcuts.
- Stop releases the player item and cancels the connection timeout.
- Pause from a remote control has the same behavior as Stop for this live stream.
- A subsequent Play request connects to the live stream again.
- iOS controls output selection.
- The app does not change the system volume.

An audio output disconnection stops playback and cancels interruption recovery.
Playback continues after a call only with the system's resume option and the same output device identifiers.
A Stop request during a call prevents subsequent automatic playback.
Apple describes output changes in [Responding to audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes).

AVPlayer handles temporary buffering.
The app allows 20 seconds for each connection or buffering period.
After an error, the user or a new Shortcut action must request playback again.
This version does not retry the connection automatically after an error.

## Settings and network access

URL validation accepts HTTP and HTTPS with a host and a valid port.
It rejects empty values, embedded credentials, whitespace in the URL, and fragments.
If validation fails, the last saved URL stays unchanged.
Saving a different valid URL stops current playback.

The URL is stored in the app's UserDefaults domain.
UserDefaults stores settings without encryption, so this version targets public stream URLs.
See [Apple's UserDefaults documentation](https://developer.apple.com/documentation/foundation/userdefaults).
The privacy manifest declares the app settings reason `CA92.1`.

HTTPS is preferred.
The media-only ATS exception permits HTTP streams loaded through AVFoundation.
It does not disable ATS for URLSession.
See [NSAllowsArbitraryLoadsForMedia](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowsarbitraryloadsformedia).
The local network usage description covers stream servers on the user's network.

## Validation limits

Core tests cover URL validation, settings preservation, duplicate Play requests, and interruption recovery decisions.
They also cover the player screen status, the Play or Stop control, and the Save button state.
They also cover control URLs and rejection of external stream overrides.
These tests do not execute AVPlayer, App Intents, or SwiftUI.
Syntax checks do not prove compatibility with the Apple SDK.
The SwiftPM target compiles for iOS with Xcode's SDK. The xtool build with the committed metadata has not been installed on a device.
The [device checks](../runbooks/iphone-setup.md#device-checks) must test the complete playback path.

The first version excludes CarPlay screens, station lists, recording, authentication, and custom codec support.
The car can use its standard Bluetooth audio controls.
Store distribution also needs release validation.
