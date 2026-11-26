# iPhone setup

## Purpose

Install Rainbrook and start its saved stream when the iPhone connects to the car's Bluetooth device.

## Prerequisites

- A computer with xtool and its iOS SDK, or a Mac with Xcode.
- An iPhone with iOS 17 or a subsequent version.
- An Apple account configured for development signing in xtool or Xcode.
- A car Bluetooth device paired with the iPhone.
- A direct Icecast MP3 or AAC stream URL.
- Network access to the stream from the iPhone.

## Install with xtool

1. Complete xtool setup on your development computer.
2. Connect the iPhone through USB.
3. Unlock the iPhone.
4. Accept the device trust request if it appears.
5. Open a terminal in the Rainbrook project root.
6. Use this command:

```sh
xtool dev
```

xtool selects the app product specified in `xtool.yml`.
It copies `Configuration/AppIntents/Metadata.appintents` into the app, then signs the app one time and installs it.
If Developer Mode is disabled, enable it and repeat the command.
Follow [xtool's device setup instructions](https://xtool.sh/tutorials/xtool/first-app/) if iOS requests developer trust.

The expected generated bundle is `xtool/Rainbrook.app`.
The build directory is excluded from Git.
If Apple reports an identifier conflict, change `bundleID` in `xtool.yml` to an identifier for your account.
The Xcode identifier is separate from this setting.

To build without installation, use:

```sh
xtool dev build
```

The initial build can require time to compile the SDK modules.
The current package declares an iOS 17 deployment target.

## Install with Xcode

1. Open `Rainbrook.xcodeproj` on the Mac.
2. Select the **Rainbrook** scheme.
3. Open the target's **Signing & Capabilities** settings.
4. Select your development team.
5. Change `org.rainbrook.Rainbrook` to a unique bundle identifier for your account.
6. Connect the iPhone to the Mac.
7. Select the iPhone as the run destination.
8. Enable Developer Mode if iOS requests it.
9. Build and run Rainbrook.

## Add a station

1. Open Rainbrook on the iPhone.
2. Tap **Settings**.
3. In the **Stations** section, tap **Add Station**.
4. Enter the **Name**, the **Stream**, the **Alternate stream**, and the **Live value address**. Only the **Stream** is necessary.
5. Tap **Save**.
6. Tap the new station to select it and start playback.

With a live value address, the player screen and Now Playing show the relay track, its artist and its artwork.
Without a live value address, or without a relay track, they show the stream title.
The Stations section shows a status message in these cases:

- The relay does not know the event.
- The event is not reserved.
- The relay client waits to connect again.

With an alternate stream, the app plays it if the stream fails (ADR 0017). The player screen shows "Alternate stream" while it plays.

## Configure playback

1. Open Rainbrook on the iPhone.
2. Tap **Settings**.
3. Set **Chime while connecting** on or off.
4. Tap **Save**.
5. Tap a station in the **Stations** section to play it.

If the chime is on, it plays in a loop until the stream starts.
When the stream plays, the status line goes away and the button shows **Stop**.
Tap the AirPlay button to select the output device.
The iPhone must play a station before you configure the automation.
For a local stream server, allow local network access when iOS requests it.

## Connect a wallet

Connect an Alby Hub wallet through Nostr Wallet Connect (NWC) for future payments.
The first version stores and tests the connection. It sends no payment.

### Paste the connection

1. In Alby Hub, make a new app connection for Rainbrook.
2. Copy the connection URI to the clipboard.
3. Open Rainbrook on the iPhone.
4. Tap **Settings**.
5. In the **Wallet** section, tap **Paste**. This is the system paste button.

The app reads the clipboard one time and saves a correct connection at once.
The relay host and the wallet key prefix appear. The Lightning address appears if the connection has one.

### Scan the QR code

1. In Alby Hub, make a new app connection for Rainbrook.
2. Show the connection QR code on a separate screen.
3. Open Rainbrook on the iPhone.
4. Tap **Settings**.
5. In the **Wallet** section, tap **Scan QR Code**.
6. Allow camera access. This request shows only after this tap.
7. Point the iPhone camera at the QR code.

The scanner closes and saves the connection after it reads a correct code.
If the device cannot run the scanner, the Wallet section shows only **Paste**.

### Test the connection

1. In the **Wallet** section, tap **Test Connection**.
2. Wait for the result. It shows within 10 seconds.

The result shows the wallet alias and the supported methods.
A warning appears if the wallet does not support keysend payments.

### Set the daily limit

1. In the **Wallet** section, select a **Daily limit** value. The default is 1000 sats.
2. Tap **Save**.

The app applies the limit after you tap Save.
This is the maximum number of sats that the app pays in one day.
This version sends no payment. A subsequent version applies the limit to each payment.

### Disconnect the wallet

1. In the **Wallet** section, tap **Disconnect**.
2. Tap **Disconnect** again in the confirmation dialog.

The app removes the stored connection at once.
After a restart of the app, the wallet stays removed.
The app does not show the secret again after it saves a connection.
Without a wallet connection, the app plays as before.

## Configure boosts

Connect a wallet before you configure boosts.

1. Open Rainbrook on the iPhone.
2. Tap **Settings**.
3. In the **Wallet** section, set **Auto-boost** on.
4. Enter the **Boost amount**, in sats.
5. Enter the **Boost message**, the **From** name and the **App name**. Each field can stay empty.
6. Enter the **Minimum play time**, in seconds.
7. Examine the **Daily limit** value.
8. Tap **Save**.

With **Auto-boost** on, the app pays one boost for a V4V track heard from its start to its end.
The track must play for the minimum play time or more.

## Send a boost

The **Boost** button is active only while a V4V track plays.

1. Tap **Boost**.
2. Change the amount, if you want a different value.
3. Write a message, if you want one.
4. Examine the split for each recipient.
5. Tap **Send**.
6. Tap **Payment details** to see the result, or tap **Close**.

## See the boost history

1. Open Rainbrook on the iPhone.
2. Tap **Settings**.
3. In the **Wallet** section, tap **Boost history**.
4. Tap an entry to see its message and the result of each part.
5. If a part can retry, tap **Retry** to send it again.

## Configure Shortcuts

### Play and Stop actions

The xtool build and the Xcode build both supply these actions.

Apple added the **Run Immediately** control for Bluetooth automations in iOS 17.
See [Apple's iOS 17 Shortcuts changes](https://support.apple.com/en-gb/111098).

1. Open Shortcuts on the iPhone.
2. Make a shortcut with the **Play Rainbrook** action.
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

Use the **Play Rainbrook** action for playback.
The **Open App** action only opens the interface.
You can make a separate shortcut with **Stop Rainbrook** for manual control.

### URL fallback

Use URL actions if Shortcuts does not show the Play and Stop actions.

1. Make a shortcut with a **URL** action set to `rainbrook://play`.
2. Add an **Open URLs** action after the URL action.
3. Use this shortcut in the Bluetooth automation.

For Stop, use `rainbrook://stop` in a separate shortcut.
The URL opens Rainbrook in the foreground, so iOS may require unlocking first.
This method does not guarantee playback from a locked phone.

## Device checks

Complete these checks before normal use of the automation.

| Check | Expected result |
| --- | --- |
| Save an invalid URL after a valid URL. | The settings sheet shows an error, stays open, and preserves the saved URL. |
| Close and reopen the app. | The saved URL remains available. |
| Run Play two times. | One stream continues without a restart. |
| Tap Play with the chime on. | The chime plays in a loop and stops when the stream starts. |
| Tap Stop while the chime plays. | The chime stops. |
| Tap Play with the chime off. | No chime plays. |
| Tap Play. | Playback starts as soon as AVPlayer is ready, with no added wait. |
| Enter a live value address in **Live value address** and play. | The artwork, the title and the artist change when the listener hears the new track. |
| Pause Mixxx during playback with a relay event configured. | The display clears when the listener hears the end of the track, not before. |
| Play "Pharaoh's Dance" with a relay event configured. | The player screen shows its artwork. |
| Play with an empty **Live value address** field, and change the track in Mixxx. | The stream title changes when the listener hears the new track. |
| Lock the screen or connect the car with a relay event configured. | The lock screen and the car show the track title, the artist and the artwork. |
| Drive through a dead zone with a relay event configured. | The display is correct within 40 seconds after the audio returns. |
| Play with an empty **Live value address** field. | The title and the artist come from the stream title, and the artwork area shows the placeholder. |
| Tap **Stop**, then **Play**, with a relay event configured. | The display is correct again. |
| Open the app before a station is saved. | The status shows **Add a station in Settings** and Play is disabled. |
| Run a Play action before a URL is saved. | The app reports missing settings. The Play Rainbrook action also reports an error to Shortcuts. |
| Lock the screen during playback. | Audio continues and Now Playing controls remain available. |
| Run Play Rainbrook while locked. | Playback starts without opening the app. |
| Run the URL fallback shortcut while locked. | iOS can require unlocking before it opens Rainbrook. |
| Open `rainbrook://play` and `rainbrook://stop`. | The saved stream starts and stops. |
| Search Shortcuts for Rainbrook after `xtool dev`. | Play Rainbrook and Stop Rainbrook appear. |
| Say "Play Rainbrook" to Siri. | Playback starts. If it fails, see [ADR 0003](../adr/0003-committed-app-intents-metadata.md#consequences). |
| Open `rainbrook://play?url=https://example.org/other`. | The app does not start playback or change the saved stream. |
| Run the automation while the app is closed. | iOS starts the action and playback begins. |
| Connect the paired car device. | The automation starts the saved stream through the selected iOS output. |
| Disconnect the audio device during playback. | Playback stops. |
| Disconnect the audio device while connecting. | The pending connection stops. |
| Receive and end a call. | Playback resumes only if iOS permits it and the output is unchanged. |
| Stop playback during a call. | Playback remains stopped after the call. |
| Remove network access during playback. | Buffering recovers or shows an error after its timeout. |
| Stop during buffering. | Playback remains stopped when network access returns. |
| While a station plays, tap a different station. | The first station stops. The new station plays. |
| Use the car's pause and play controls. | Pause stops the stream. Play reconnects to live audio. |
| Enable VoiceOver and large text. | Labels remain clear and all controls remain accessible. |
| Use **Paste** with a URI from Alby Hub. | The app saves the connection, and the secret does not show. |
| Use Scan QR Code with the connection QR code from Alby Hub on another screen. | The scanner reads the code and saves the connection. |
| Tap Scan QR Code. | The camera permission request shows only after this tap. |
| Tap Test Connection. | The wallet methods show within 10 seconds. |
| Tap Disconnect, then restart the app. | The wallet stays removed after the restart. |
| Restart the phone and unlock it one time. | A background test can read the stored connection while the phone is locked. |
| Turn on **Auto-boost** and play a V4V track to its end. | The app pays one boost. The wallet shows the payment, and the history shows the entry. |
| Join a V4V track already playing, in the middle. | No auto-boost occurs. |
| Play a track that is not V4V. | No auto-boost occurs, and the **Boost** button is not active. |
| Turn off **Auto-boost** and play a V4V track to its end. | No auto-boost occurs. |
| Play a V4V track with Auto-boost over the remaining daily limit. | No auto-boost occurs, and the result names the reason. |
| Lock the screen during an auto-boost. | The auto-boost still occurs. |
| Send a manual boost with a message. | The app pays the track that plays. The recipient sees the message and the sender name. |
| Examine the history after a boost. | Each recipient shows confirmed, failed or unknown. |
| Change the amount in the boost sheet. | The split changes for the new amount. |
| Tap **Payment details** after a manual boost. | The history entry of that boost opens. |
| Play a V4V track and look at the player screen. | The **Boost** button is active, and it opens the boost sheet. |
| Play "Nowhere Anywhere". | Its artwork shows. |
| Play "How Bout You?". | Its GIF shows and moves. |
| Play "Disco Swag". | Its GIF shows and moves. |
| Lock the screen during a GIF track. | The lock screen shows the first frame of the GIF. |
| Play a track with a relay image. | Its artwork shows as before. |
| Set **Minimum play time** to 60 and play a V4V track for 20 seconds. | No auto-boost occurs, and the result names the reason. |
| Set "Track duplicate distance" to 0 in Mixxx, then switch back to a V4V track. | An auto-boost occurs if the track plays for the minimum play time. |
| Examine a failed part in the history. | Its reason shows. |
| Wait about 1 minute after a failed keysend part. | The app sends the part again, and the history entry shows the new result. |
| Tap **Retry** in a history entry. | The app sends the failed parts again. |
| Open the app after the update, with an old stream saved. | The old stream and the live value address show as one selected station. |
| Tap a station in the list. | The station plays. Its artwork and its title show. |
| Give a station a primary stream that does not work. | The station plays the alternate stream after a maximum of 20 seconds. The player screen shows "Alternate stream". |
| Play a station with an HLS stream. | The title and the artwork of the track show. |
| Say "Play Rainbrook" with more than one station saved. | The selected station plays. |
| Tap **Play** on a V4V track. | **Boost** is active for the first track (ADR 0018). |
| Tap **Play** in the first minute of a new V4V track. | **Boost** is active, and the boost pays that track (ADR 0018). |
| Play a track with an album. | The album shows below the artist, and the lock screen shows it (ADR 0019). |
| Play a track with no album. | No empty line shows below the artist (ADR 0019). |
| On HLS, set **Stream quality** to **Low**. | The server log shows requests for `aac_low` segments (ADR 0020). |
| On HLS, turn flight mode on for 15 seconds, then off. | Playback continues with no stall (ADR 0020). |
| On Icecast, play with each **Stream quality** value. | Playback works as before (ADR 0020). |
| On HLS, set **HLS buffer** to 90 seconds, then tap **Play**. | A network problem of 60 seconds gives no stall (ADR 0020). |
| On Icecast, turn flight mode on for 10 seconds, then off. | No chime for 3 seconds, then the chime. Playback continues with no error (ADR 0021). |
| Turn flight mode on for 2 minutes, then off. | The screen shows "Waiting for the network". Playback continues after flight mode is off (ADR 0021). |
| Stop the stream on the server while the iPhone has a network. | After about 60 seconds, the alternate stream plays, or the error shows (ADR 0021). |

Also test the locked automation after you restart and unlock the iPhone.
Record the actual behavior after force-quitting the app, because iOS can prevent background launches.
Simulator checks cannot replace the car and iPhone checks.

## Commands

Run all checks from the project root before a commit:

```sh
scripts/check.sh
```

The script runs the core tests, the iOS build in Swift 6 language mode, and the App Intents symbol check.

On a Mac, compile the iOS target without device signing:

```sh
xcodebuild \
  -project Rainbrook.xcodeproj \
  -scheme Rainbrook \
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
| `xtool` is not found. | Install xtool and add it to the terminal's PATH. |
| xtool reports no iOS SDK. | Complete `xtool setup` on the development computer. |
| xtool reports an identifier conflict. | Set a unique `bundleID` in `xtool.yml`. |
| An xtool installation has no named Play action. | Examine `resources` in `xtool.yml`, then run `xtool dev` again. Use the URL shortcut until the actions show. |
| Play or Stop Rainbrook reports an internal error. | Run `llvm-nm xtool/Rainbrook.app/Rainbrook \| grep 9Rainbrook15PlayRadioIntentV`. If it shows no symbols, the binary has no intents. See [ADR 0003](../adr/0003-committed-app-intents-metadata.md). |
| The URL shortcut requires unlocking. | Unlock the phone, or test the App Intent through an Xcode build. |
| Xcode reports a signing error. | Select your development team and a unique bundle identifier. |
| Shortcuts cannot find Rainbrook. | Open the installed app, then search for its actions again. |
| The app opens but audio does not start. | Use the Play Rainbrook action in the automation. |
| The automation asks before running. | Check its automatic execution and locked-device settings. |
| The stream fails immediately. | Examine the direct URL and MP3 or AAC format. |
| The connection times out. | Check network access and the stream server, then request Play again. |
| Audio uses the iPhone speaker. | Select the car audio output in Control Center. |
| A home server fails in the car. | Use a stream address reachable through the iPhone's cellular connection. |
| Audio remains stopped after a call. | Request Play again after the call. |

## Rollback

1. Disable or remove the Bluetooth automation in Shortcuts.
2. Tap **Stop Radio** in Rainbrook.
3. Remove the app if you no longer need it.

Removing the app deletes its saved stream setting from the device.

See the [architecture overview](../architecture/overview.md) for playback rules and platform references.
