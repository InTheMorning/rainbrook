# ADR 0006: Audio session activation off the main thread

- Status: accepted
- Date: 2026-10-04
- Class: situational. Supersede this record when the deployment target is iOS 27 or later and the app uses the asynchronous activation API.

## Context

The Xcode hang checker reported "AVAudioSession Hang Risk" four times on a device run of commit `b083f83`:

- `RadioPlayer.swift:92`: `setActive(true)` in `play()`.
- `RadioPlayer.swift:258`, two times: `setActive(false)` in `deactivateSession()`.
- `RadioPlayer.swift:275`: the chime `AVAudioPlayer.play()`. It activates an inactive audio session on the calling thread.

All these calls ran on the main thread. `setActive` can block, and the user interface then stops responding.

The iOS SDK has `activate(options:completionHandler:)` and `deactivate(options:completionHandler:)`. They are available from iOS 27. The app supports iOS 17.

## Decision

- `RadioPlayer` sets the audio session category and activates the session on its serial queue `sessionQueue`.
- `RadioPlayer` deactivates the session on the same queue. The serial queue keeps activation and deactivation in their sequence.
- `play()` sets the state to `connecting` and starts the connection timeout immediately. It creates the `AVPlayer` only after activation is complete and the session ID is unchanged.
- An activation error stops playback with the error message, as before.
- The chime starts only after activation is complete, so `AVAudioPlayer` does not activate the session itself.

## Alternatives considered

- Use the iOS 27 asynchronous API with an `if #available` branch. The app would then have two code paths, and the queue is necessary for iOS 17 to 26.
- Keep the calls on the main thread. The hang checker reports a risk of an unresponsive interface.

## Consequences

- A second Play request during activation does not start a second connection.
- A Stop request during activation releases the session ID, so the pending activation does not start a player.
- The hang checker runs only in Xcode. On Linux, `AudioSessionThreadTests` is the guard.

## Invariants

- Each `setActive(` call in the app sources runs inside a dispatch queue block.
  `AudioSessionThreadTests.testAudioSessionActivationRunsOffTheMainThread` enforces this rule.
- The chime starts only when the session is active.
  Manual check: Xcode's hang checker on a device run. A Linux test cannot observe the implicit activation.
