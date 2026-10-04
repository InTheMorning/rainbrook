# CitizenRadio

CitizenRadio is a native iPhone app for one Icecast stream.
Enter the stream URL in the app, then save it.
A Bluetooth automation in Shortcuts can run **Play CitizenRadio** when your iPhone connects to your car.

## First run

1. Open `CitizenRadio.xcodeproj` in Xcode on a Mac.
2. Select the **CitizenRadio** target.
3. Select your development team in **Signing & Capabilities**.
4. Change the bundle identifier to a unique identifier for your account.
5. Select your iPhone as the run destination.
6. Build and run the app.
7. Enter your direct MP3 or AAC stream URL.
8. Tap **Save Stream**, then **Play Radio**.

The deployment target is iOS 17.
Use Xcode 15 or a subsequent version that supports your iPhone's installed iOS version.
The project has no external dependencies.

## Current implementation

- The app saves one HTTP or HTTPS stream URL.
- Play and Stop actions are available through App Intents.
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

Ten core tests passed on Linux during initial development.
Swift syntax checks also passed.
The iOS target has not been compiled with an Apple SDK in this workspace.
Use an iPhone to test audio, Shortcuts, Bluetooth, and locked-screen behavior.
This first version has no custom app icon.

## Documentation

- [iPhone setup and device checks](docs/runbooks/iphone-setup.md)
- [Architecture and platform references](docs/architecture/overview.md)
