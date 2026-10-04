# CitizenRadio

CitizenRadio is a native iPhone app for one Icecast stream.
Enter the stream URL in the app settings, then save it.
A Bluetooth automation in Shortcuts can start playback when your iPhone connects to your car.

## Install with xtool

Complete [xtool setup](https://xtool.sh/tutorials/xtool/first-app/) on your development computer.
Connect and unlock your iPhone.
From the project root, use:

```sh
scripts/xtool-install.sh
```

The script runs on macOS and Linux and needs `python3` (Arch: `sudo pacman -S python`).
It builds and signs the app with xtool, adds the App Intents metadata that Xcode would generate, and installs the app.
Plain `xtool dev` also installs the app, but Shortcuts then has no **Play CitizenRadio** or **Stop CitizenRadio** actions.

The configuration selects the `CitizenRadio` app product and includes the icon, privacy manifest, and background audio settings.
The generated app is `xtool/CitizenRadio.app`.
Change `bundleID` in `xtool.yml` if Apple reports an identifier conflict.
The deployment target is iOS 17.
The project has no external dependencies.

Open the installed app and tap **Settings**.
Enter your direct MP3 or AAC stream URL, then tap **Save**.
Tap **Play**.

Use the **Play CitizenRadio** and **Stop CitizenRadio** actions in your car's Bluetooth automations.
See the [setup guide](docs/runbooks/iphone-setup.md).

xtool cannot generate App Intents metadata ([xtool issue 145](https://github.com/xtool-org/xtool/issues/145)).
The repository keeps a copy that Xcode generated in `Configuration/AppIntents/Metadata.appintents`.
After you change `CitizenRadio/RadioIntents.swift`, run `scripts/generate-app-intents-metadata.sh` on a Mac with Xcode and commit the result.

## Install with Xcode

1. Open `CitizenRadio.xcodeproj` in Xcode on a Mac.
2. Select the **CitizenRadio** target.
3. Select your development team in **Signing & Capabilities**.
4. Change the bundle identifier to a unique identifier for your account.
5. Select your iPhone as the run destination.
6. Build and run the app.
7. Tap **Settings** and enter your direct MP3 or AAC stream URL.
8. Tap **Save**, then **Play**.

Use Xcode 15 or a subsequent version that supports your iPhone's installed iOS version.
The Xcode build includes the named **Play CitizenRadio** and **Stop CitizenRadio** App Intents.

## Current implementation

- The player screen shows an artwork placeholder, the playback status, Play or Stop, and the AirPlay button.
- The settings sheet saves one HTTP or HTTPS stream URL.
- An optional chime plays in a loop while the stream connects. The chime is on by default.
- Play and Stop URL actions are available in each build.
- Each build supplies the Play and Stop App Intents. The xtool build gets them through `scripts/xtool-install.sh`.
- The audio session supports background playback.
- The player supplies Now Playing information and remote playback controls.
- An audio device disconnection stops playback.
- Playback can continue after a call if iOS permits it and the output device is unchanged.
- A connection or buffering timeout of 20 seconds stops playback with an error.

Icecast supplies the stream transport. Its audio codec must also work with AVPlayer.
This version targets direct MP3 and AAC streams.
It does not parse playlist files or add an Ogg decoder.

## Checks

Run the core tests with:

```sh
swift test
```

Twenty-six core tests passed on Linux after the chime change.
The iOS source syntax check also passed.
This workspace has no xtool executable or iOS SDK.
The iOS target has not been compiled or installed here.
Use an iPhone to test audio, Shortcuts, Bluetooth, and locked-screen behavior.
The app icon uses the PNG in the `AppIcon` asset catalog.
xtool copies that PNG through its `iconPath` configuration.

## Documentation

- [iPhone setup and device checks](docs/runbooks/iphone-setup.md)
- [Architecture and platform references](docs/architecture/overview.md)
- [ADR 0002: Player screen and settings](docs/adr/0002-player-screen-and-settings.md)
