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

RadioView -> StreamStore -> UserDefaults
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
| `RadioView` | Edits the URL and shows playback controls, status, and output. |
| `StreamAddress` | Validates the URL before storage or playback. |
| `StreamStore` | Reads and writes the saved URL. |
| `PlaybackRequest` | Controls if playback can continue after an interruption. |
| `RadioPlayer` | Owns AVPlayer, the audio session, observers, and remote controls. |
| `PlayRadioIntent` | Starts the saved stream and waits for playback. |
| `StopRadioIntent` | Stops playback and cancels pending connection work. |
| `RadioShortcuts` | Makes the Play and Stop actions discoverable. |

The Xcode target compiles all seven Swift source files into the app.
The Swift package compiles only the three core files for tests on Linux or macOS.
The app has one player instance on the main actor.
Its intents are in the app target and use that same instance.

## Playback rules

The two intents adopt `AudioPlaybackIntent` and set `openAppWhenRun` to `false`.
Apple defines this protocol for intents that change audio playback.
See [AudioPlaybackIntent](https://developer.apple.com/documentation/appintents/audioplaybackintent).

The audio session uses the playback category.
The app declares the `audio` background mode.
Apple documents this mode for audio content that continues in the background.
See [background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes).

- A repeated Play request keeps an active connection to the same stream.
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
These tests do not execute AVPlayer, App Intents, or SwiftUI.
Syntax checks do not prove compatibility with the Apple SDK.
The [device checks](../runbooks/iphone-setup.md#device-checks) must test the complete playback path.

The first version excludes CarPlay screens, station lists, recording, authentication, and custom codec support.
The car can use its standard Bluetooth audio controls.
Store distribution also needs an app icon and release validation.
