# iPhone setup

## Purpose

Install CitizenRadio and start its saved stream when the iPhone connects to the car's Bluetooth device.

## Prerequisites

- A Mac with Xcode and support for the iPhone's installed iOS version.
- An iPhone with iOS 17 or a subsequent version.
- An Apple account configured for development signing in Xcode.
- A car Bluetooth device paired with the iPhone.
- A direct Icecast MP3 or AAC stream URL.
- Network access to the stream from the iPhone.

## Install and configure

1. Open `CitizenRadio.xcodeproj` on the Mac.
2. Select the **CitizenRadio** scheme.
3. Open the target's **Signing & Capabilities** settings.
4. Select your development team.
5. Change `org.citizenradio.CitizenRadio` to a unique bundle identifier for your account.
6. Connect the iPhone to the Mac.
7. Select the iPhone as the run destination.
8. Enable Developer Mode if iOS requests it.
9. Build and run CitizenRadio.
10. Enter the stream URL in **Stream URL**.
11. Tap **Save Stream**.
12. Tap **Play Radio**.

The expected status is **Playing live**.
The audio output row shows the current output device.
The iPhone must play the stream before you configure the automation.
For a local stream server, allow local network access when iOS requests it.

## Configure Shortcuts

Apple added the **Run Immediately** control for Bluetooth automations in iOS 17.
See [Apple's iOS 17 Shortcuts changes](https://support.apple.com/en-gb/111098).

1. Open Shortcuts on the iPhone.
2. Make a shortcut with the **Play CitizenRadio** action.
3. Run the shortcut to test playback.
4. Add a Bluetooth automation for your car's paired device.
5. Select the connection trigger.
6. Configure the automation to run the shortcut.
7. Select **Run Immediately** if that option appears.
8. Enable execution while locked if Shortcuts provides that setting.

The automation controls depend on the installed iOS version.
Some versions create automations from the Automation tab.
Newer layouts can attach a trigger to an existing shortcut.
Apple's [automation guide](https://support.apple.com/guide/shortcuts/add-automations-apdfbdbd7123/ios) describes the current controls.

Use the **Play CitizenRadio** action for playback.
The **Open App** action only opens the interface.
You can make a separate shortcut with **Stop CitizenRadio** for manual control.

## Device checks

Complete these checks before normal use of the automation.

| Check | Expected result |
| --- | --- |
| Save an invalid URL after a valid URL. | The app shows an error and preserves the saved URL. |
| Close and reopen the app. | The saved URL remains available. |
| Run Play two times. | One stream continues without a restart. |
| Run Play before a URL is saved. | Shortcuts reports that a stream URL is required. |
| Lock the screen during playback. | Audio continues and Now Playing controls remain available. |
| Run the automation while locked. | Playback starts without opening the app. |
| Run the automation while the app is closed. | iOS starts the action and playback begins. |
| Connect the paired car device. | The automation starts the saved stream through the selected iOS output. |
| Disconnect the audio device during playback. | Playback stops. |
| Disconnect the audio device while connecting. | The pending connection stops. |
| Receive and end a call. | Playback resumes only if iOS permits it and the output is unchanged. |
| Stop playback during a call. | Playback remains stopped after the call. |
| Remove network access during playback. | Buffering recovers or shows an error after its timeout. |
| Stop during buffering. | Playback remains stopped when network access returns. |
| Change and save the stream URL. | Current playback stops. The next Play uses the new URL. |
| Use the car's pause and play controls. | Pause stops the stream. Play reconnects to live audio. |
| Enable VoiceOver and large text. | Labels remain clear and all controls remain accessible. |

Also test the locked automation after you restart and unlock the iPhone.
Record the actual behavior after force-quitting the app, because iOS can prevent background launches.
Simulator checks cannot replace the car and iPhone checks.

## Commands

Run the core tests from the project root:

```sh
swift test
```

On a Mac, compile the iOS target without device signing:

```sh
xcodebuild \
  -project CitizenRadio.xcodeproj \
  -scheme CitizenRadio \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected results are zero test failures and `BUILD SUCCEEDED` from Xcode.
The Xcode scheme has no test target.
The core tests run through the Swift package.

## Failure modes

| Symptom | Action |
| --- | --- |
| Xcode reports a signing error. | Select your development team and a unique bundle identifier. |
| Shortcuts cannot find CitizenRadio. | Open the installed app, then search for its actions again. |
| The app opens but audio does not start. | Use the Play CitizenRadio action in the automation. |
| The automation asks before running. | Check its automatic execution and locked-device settings. |
| The stream fails immediately. | Examine the direct URL and MP3 or AAC format. |
| The connection times out. | Check network access and the stream server, then request Play again. |
| Audio uses the iPhone speaker. | Select the car audio output in Control Center. |
| A home server fails in the car. | Use a stream address reachable through the iPhone's cellular connection. |
| Audio remains stopped after a call. | Request Play again after the call. |

## Rollback

1. Disable or remove the Bluetooth automation in Shortcuts.
2. Tap **Stop Radio** in CitizenRadio.
3. Remove the app if you no longer need it.

Removing the app deletes its saved stream setting from the device.

See the [architecture overview](../architecture/overview.md) for playback rules and platform references.
