# CitizenRadio

CitizenRadio is a native iPhone app for one Icecast stream.
Enter the stream URL in the app settings, then save it.
A Bluetooth automation in Shortcuts can start playback when your iPhone connects to your car.

## Install with xtool

Complete [xtool setup](https://xtool.sh/tutorials/xtool/first-app/) on your development computer.
Connect and unlock your iPhone.
From the project root, use:

```sh
xtool dev
```

The configuration selects the `CitizenRadio` app product and includes the icon, privacy manifest, and background audio settings.
The generated app is `xtool/CitizenRadio.app`.
Change `bundleID` in `xtool.yml` if Apple reports an identifier conflict.
The deployment target is iOS 17.
The project has no external dependencies.

Open the installed app and tap **Settings**.
Enter your direct MP3 or AAC stream URL, then tap **Save**.
Tap **Play**.

For this build, make a shortcut with a **URL** action containing `citizenradio://play` and an **Open URLs** action.
Use that shortcut in your car's Bluetooth automation.
The URL opens the app, so iOS may require you to unlock the phone.
Current xtool packaging does not provide the App Intents metadata needed for the named **Play CitizenRadio** action.
See [xtool issue 145](https://github.com/xtool-org/xtool/issues/145) and the [setup guide](docs/runbooks/iphone-setup.md).

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
- The Xcode build also supplies App Intents.
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
