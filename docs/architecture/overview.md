# Rainbrook architecture

## Purpose

Rainbrook plays one saved Icecast stream after a user action or a Shortcuts automation.
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

SettingsView -> StationEditorView -> StationStore -> UserDefaults
PlayRadioIntent -> RadioPlayer -> StationStore -> Selected station

SettingsView -> WalletSettingsModel -> WalletStore -> KeychainSecretStore
WalletSettingsModel -> NWCClient -> URLSessionRelayConnection -> relay

relay /display/events -> EventStreamClient -> TrackInfoModel -> PlayerView and Now Playing
AVPlayer ICY metadata -> IcyMetadataReader -> RadioPlayer.icyText -> IcySync in TrackInfoModel

relay /events (remoteValue) -> EventStreamClient -> BoostModel (BoostPairing)
ICY text -> TrackInfoModel -> BoostModel (BoostTrigger) -> BoostPlan -> BoostPayer -> NWCClient and LNURL -> BoostHistory
Boost button -> BoostSheet -> BoostModel.sendManualBoost -> BoostPayer -> BoostHistory
```

Shortcuts owns the Bluetooth trigger.
Rainbrook does not scan for Bluetooth devices or request location access.
Apple supports a trigger for a selected Bluetooth device.
See [Apple's setting triggers](https://support.apple.com/guide/shortcuts/setting-triggers-apde31e9638b/ios).

## Components

| Component | Responsibility |
| --- | --- |
| `RainbrookApp` | Creates the SwiftUI scene. |
| `PlayerView` | Shows the artwork placeholder, status, Play or Stop, the AirPlay button, and the Boost button (ADR 0014). |
| `SettingsView` | Shows the station list and the other settings in a sheet. |
| `StationEditorView` | Adds a station or changes a station (ADR 0017). |
| `PlaybackState` | Names the playback states and their status titles. |
| `ChimeSetting` | Stores the chime setting and selects the states that play the chime. |
| `LoadedAudio` | Measures the loaded audio ahead of the play position, for the display delay. |
| `PlayerScreenModel` | Selects the status text and the Play or Stop control for the player screen. |
| `StreamSettingsDraft` | Enables Save for a changed chime, daily limit or boost setting. |
| `StreamAddress` | Validates the URL before storage or playback. |
| `Station` | Holds and validates the name, the streams and the live value address of a station (ADR 0017). |
| `StationStore` | Reads and writes the station list and the selected station in UserDefaults (ADR 0017). |
| `PlaybackRequest` | Controls if playback can continue after an interruption. |
| `RadioURLAction` | Accepts the Play and Stop control URLs. |
| `RadioPlayer` | Owns AVPlayer, the audio session, observers, and remote controls. It plays the alternate stream when the primary stream fails (ADR 0017). |
| `PlayRadioIntent` | Starts the selected station and waits for playback. |
| `StopRadioIntent` | Stops playback and cancels pending connection work. |
| `RadioShortcuts` | Makes the Play and Stop actions discoverable. |
| `NWCConnection` | Parses and validates a Nostr Wallet Connect connection URI. |
| `WalletSummary` | Holds the wallet facts that the settings sheet shows for a connected wallet. |
| `SpendingLimit` | Holds the daily sats limit and the quantity spent today. |
| `NostrKeys` | Makes and checks Schnorr signatures for Nostr events. |
| `NostrEvent` | Builds and signs a Nostr event. |
| `NIP44` | Encrypts and decrypts wallet messages with NIP-44 version 2. |
| `NIP04` | Encrypts and decrypts wallet messages for an older wallet with NIP-04. |
| `RelayMessage` | Names the relay filter and the client and relay messages of NIP-01. |
| `RelayConnection` | Sends and receives relay text messages for NWCClient. |
| `NWCClient` | Sends a wallet info request to the relay and reads the reply. |
| `SecretStore` | Reads, writes and deletes the stored wallet connection URI. |
| `WalletStatusText` | Selects the status text for the Wallet section of Settings. |
| `KeychainSecretStore` | Stores the wallet connection URI in the Keychain. |
| `URLSessionRelayConnection` | Opens a relay connection with a WebSocket task. |
| `WalletSettingsModel` | Selects the state and controls for the Wallet section of Settings. |
| `WalletSettingsView` | Shows the paste, scan, test and disconnect controls for the wallet. |
| `QRScannerView` | Scans a QR code and returns the wallet connection text. |
| `RelayEvent` | Parses and validates the relay event address for the Live value address setting. |
| `EventStreamParser` | Parses server-sent event lines into named events. |
| `EventStreamClient` | Reads the relay snapshot, opens the event stream, and applies the reconnect and backoff rules. |
| `TrackDisplay` | Decodes the relay display state into a track with an artist, a title and artwork. |
| `IcyTitle` | Parses the Icecast StreamTitle text into an artist and a title. |
| `DisplayTiming` | Computes the wait before the app applies a streamed display state. |
| `TrackLines` | Selects the title, the artist and the artwork to display, with the relay track as the priority. |
| `IcySync` | Keeps the last display states, and selects the relay track that the ICY text or the HLS segment frame names (ADR 0011, ADR 0024, ADR 0030). |
| `ArtworkPolicy` | Accepts or rejects artwork data, and gives its cache key. |
| `ArtworkFrames` | Selects the frames and the delays of an animated image, in the URL artwork limits (ADR 0015). |
| `LRUCache` | Holds a fixed number of entries, and removes the oldest entry first. |
| `RelayStatusText` | Selects the relay status text for the Live value address section of Settings. |
| `NetworkPathSummary` | Holds one network path update, and tells if a reconnect is necessary. |
| `URLSessionEventStream` | Opens the relay event stream and reads the relay snapshot with URLSession. |
| `NetworkPathMonitor` | Watches the network path with NWPathMonitor. |
| `ArtworkLoader` | Downloads and decodes track artwork off the main thread, with a memory cache. |
| `IcyMetadataReader` | Reads the Icecast stream title, or the ID3 items and the segment frame of an HLS stream, from the playing item, off the main thread. |
| `TrackInfoModel` | Runs the relay client while playback is connecting or playing, and selects the track and the artwork for the player screen and Now Playing. |
| `LiveValue` | Holds a live value payload and its payable destinations (ADR 0013). |
| `BoostPairing` | Selects the live value payload that pays a completed relay track (ADR 0013). |
| `BoostTrigger` | Decides when the listener heard a track from its start to its end, tells a switch back from a repeat, and ends a candidate at a chapter change (ADR 0013, ADR 0016, ADR 0024). |
| `BoostSettings` | Stores the auto-boost settings and the minimum play time (ADR 0013, ADR 0016). |
| `BoostPlan` | Decides if the app pays a boost, and gives its parts or its skip reason (ADR 0013, ADR 0016). |
| `BoostSplit` | Divides a boost amount among the payable destinations (ADR 0013). |
| `BoostRecord` | Holds the message, the sender name and the app name of a boost (ADR 0013). |
| `NWCPayment` | Holds the keysend and the lightning address data for one NWC payment. |
| `Bolt11` | Reads the amount of a BOLT11 invoice. |
| `LightningAddress` | Makes the LNURL-pay request and checks its answer for a lightning address payment (ADR 0013). |
| `BoostPayer` | Pays the parts of a boost through NWC and LNURL, and retries failed parts (ADR 0013, ADR 0016). |
| `BoostStatusText` | Selects the boost result text for the Wallet section of Settings. |
| `BoostHistory` | Keeps the last 200 boosts, newest first, in a file (ADR 0013, ADR 0016). |
| `BoostModel` | Decides and pays the auto-boosts and the manual boosts of a session, and keeps the history (ADR 0013, ADR 0016). |
| `BoostSheet` | Shows the split of a manual boost, sends it, and shows the payment details (ADR 0013 §Manual boost). |
| `BoostHistoryView` | Shows the boost history, and a Retry button for a failed part (ADR 0013, ADR 0016). |

The Xcode target compiles all sixty-seven Swift source files into the app.
The Swift package exposes the `Rainbrook` app library and an internal `RainbrookCore` target.
The app target depends on the core target.
Its four UI and playback files use an iOS compilation condition so host tests do not need Apple frameworks.
The app has one player instance on the main actor.
Its URL actions and App Intents use that same instance.

## xtool packaging

`xtool.yml` selects the `Rainbrook` library product for the app.
xtool supplies the executable entry point from the app's SwiftUI `@main` declaration.
The package and the Xcode target use Swift 6 language mode and an iOS 17 deployment target.
`scripts/check.sh` runs the core tests and the iOS build. See [ADR 0005](../adr/0005-swift-6-and-check-script.md).

`Configuration/xtool-info.plist` supplies literal runtime settings.
It contains no Xcode build variables.
xtool supplies the bundle identifier, executable name, and minimum OS version from its configuration and the package.
The overrides retain background audio, HTTP media access, local network access text, and iPhone orientations.
The icon uses `iconPath`. The privacy manifest, `chime.wav` and the App Intents metadata use the root `resources` list.
See xtool's [configuration schema](https://github.com/xtool-org/xtool/blob/main/Sources/PackLib/PackSchema.swift) and [plist assembly](https://github.com/xtool-org/xtool/blob/main/Sources/PackLib/Planner.swift).

The Swift package compiles `RadioIntents.swift` like the Xcode target.
xtool does not extract App Intents metadata ([issue 145](https://github.com/xtool-org/xtool/issues/145)).
Its [packer](https://github.com/xtool-org/xtool/blob/main/Sources/PackLib/Packer.swift) has no metadata stage.
`Configuration/AppIntents/Metadata.appintents` holds the metadata that Xcode generates, made by `scripts/generate-app-intents-metadata.sh`.
It names the intent types by module (`Rainbrook`) and mangled type name, which match in both builds.
xtool copies this directory to the app bundle root before it signs the app, so `xtool dev` signs one time.
Do not add files to an app that xtool signed, and do not install a signed app again with `xtool install`.
xtool signs again and adds a second `XTL-<team>.` prefix to the bundle ID.
See [ADR 0003](../adr/0003-committed-app-intents-metadata.md).

As a fallback, Shortcuts can use **Open URLs** with `rainbrook://play` or `rainbrook://stop`.
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
- The player activates and deactivates the audio session on a serial background queue, not on the main thread. See [ADR 0006](../adr/0006-audio-session-off-main-thread.md).
- If the chime setting is on, `chime.wav` plays in a loop while the state is `connecting`. It stops at all other states.
- AVPlayer controls the buffer. After a stall, the state is `connecting` and the player calls `play()` again. See [ADR 0014](../adr/0014-player-screen-with-boost-button.md).
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
