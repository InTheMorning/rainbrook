# Rainbrook

Rainbrook is a native iPhone app for an Icecast or HLS radio station.
Add a station in the app settings, then play it.
A Bluetooth automation in Shortcuts can start playback when your iPhone connects to your car.

## Install with xtool

Complete [xtool setup](https://xtool.sh/tutorials/xtool/first-app/) on your development computer.
Connect and unlock your iPhone.
From the project root, use:

```sh
xtool dev
```

xtool builds the app, signs it one time with your Apple account, and installs it.
The app includes the committed App Intents metadata, so Shortcuts shows **Play Rainbrook** and **Stop Rainbrook**.

The configuration selects the `Rainbrook` app product and includes the icon, privacy manifest, and background audio settings.
The generated app is `xtool/Rainbrook.app`.
Change `bundleID` in `xtool.yml` if Apple reports an identifier conflict.
The deployment target is iOS 17.
The project depends on swift-secp256k1 and swift-crypto for the wallet connection.

Open the installed app and tap **Settings**.
Tap **Add Station**, enter a name and a direct MP3 or AAC stream URL, then tap **Save**.
Tap the new station to start playback.

Use the **Play Rainbrook** and **Stop Rainbrook** actions in your car's Bluetooth automations.
See the [setup guide](docs/runbooks/iphone-setup.md).

xtool cannot generate App Intents metadata ([xtool issue 145](https://github.com/xtool-org/xtool/issues/145)).
The repository keeps a copy that Xcode generated in `Configuration/AppIntents/Metadata.appintents`.
After you change `Rainbrook/RadioIntents.swift`, run `scripts/generate-app-intents-metadata.sh` on a Mac with Xcode and commit the result.

## Install with Xcode

1. Open `Rainbrook.xcodeproj` in Xcode on a Mac.
2. Select the **Rainbrook** target.
3. Select your development team in **Signing & Capabilities**.
4. Change the bundle identifier to a unique identifier for your account.
5. Select your iPhone as the run destination.
6. Build and run the app.
7. Tap **Settings**, tap **Add Station**, and enter a name and a direct MP3 or AAC stream URL.
8. Tap **Save**, then tap the new station to start playback.

Use Xcode 15 or a subsequent version that supports your iPhone's installed iOS version.
The Xcode build includes the named **Play Rainbrook** and **Stop Rainbrook** App Intents.

## Current implementation

- The player screen shows an artwork placeholder, the playback status, Play or Stop, and the AirPlay button.
- The settings sheet has a Stations section for a maximum of 20 stations. Each station has a stream, an optional alternate stream, and an optional live value address. The app plays the alternate stream if the stream fails.
- An optional chime plays in a loop while the stream connects. The chime is on by default.
- Play and Stop URL actions are available in each build.
- Each build supplies the Play and Stop App Intents. The xtool build gets their metadata through the `resources` list in `xtool.yml`.
- The audio session supports background playback.
- The player supplies Now Playing information and remote playback controls.
- An audio device disconnection stops playback.
- Playback can continue after a call if iOS permits it and the output device is unchanged.
- A connection or buffering timeout of 20 seconds stops playback with an error.
- The settings sheet has a Wallet section to connect, test and disconnect a Nostr Wallet Connect wallet, with a daily sats limit.
- Each station can have a live value address for the relay event. The player screen and Now Playing show the relay track and its artwork when the stream title names that track. Else they show the stream title.
- The player screen shows an animated GIF when the artwork of a track comes from a URL. Now Playing shows the first frame.
- With a connected wallet, the app can pay an auto-boost for a track the listener hears to its end. The listener can also send a manual boost with a message, and see each result in the Boost history screen.

Icecast supplies the stream transport. Its audio codec must also work with AVPlayer.
This version targets direct MP3 and AAC streams.
It does not parse playlist files or add an Ogg decoder.

## Checks

Run all checks before a commit:

```sh
scripts/check.sh
```

The script runs the core tests, builds the iOS app with xtool in Swift 6 language mode, and makes sure that the App Intents are in the binary.
It needs `xtool` and `llvm-nm` on the PATH.
See [ADR 0005](docs/adr/0005-swift-6-and-check-script.md).
Use an iPhone to test audio, Shortcuts, Bluetooth, and locked-screen behavior.
The app icon uses the PNG in the `AppIcon` asset catalog.
xtool copies that PNG through its `iconPath` configuration.

## Documentation

- [iPhone setup and device checks](docs/runbooks/iphone-setup.md)
- [Architecture and platform references](docs/architecture/overview.md)
- [ADR 0003: Committed App Intents metadata](docs/adr/0003-committed-app-intents-metadata.md)
- [ADR 0005: Swift 6 and the check script](docs/adr/0005-swift-6-and-check-script.md)
- [ADR 0006: Audio session activation off the main thread](docs/adr/0006-audio-session-off-main-thread.md)
- [ADR 0007: NWC wallet configuration](docs/adr/0007-nwc-wallet-configuration.md)
- [ADR 0008: Track metadata and artwork from the relay](docs/adr/0008-relay-display-metadata.md)
- [ADR 0011: ICY sync of the relay display](docs/adr/0011-icy-sync-of-the-relay-display.md)
- [ADR 0013: Boosts](docs/adr/0013-boosts.md)
- [ADR 0014: Player screen with the Boost button](docs/adr/0014-player-screen-with-boost-button.md)
- [ADR 0015: Artwork from a URL and animated GIF images](docs/adr/0015-artwork-from-url-and-animated-gif.md)
- [ADR 0016: Boost switch back, minimum play time and retry](docs/adr/0016-boost-switch-back-play-time-and-retry.md)
- [ADR 0017: Stations with an alternate stream](docs/adr/0017-stations-with-alternate-stream.md)
- [Research: musicindex relay metadata](docs/research/musicindex-relay-metadata.md)
- [Relay display phase plan](docs/plans/relay-display-phase-plan.md)
- [ICY sync phase plan](docs/plans/icy-sync-plan.md)
- [Auto-boost phase plan](docs/plans/auto-boost-plan.md)
- [NWC wallet phase plan](docs/plans/nwc-wallet-phase-plan.md)
