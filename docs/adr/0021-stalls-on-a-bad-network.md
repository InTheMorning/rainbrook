# ADR 0021: Stalls on a bad network

- Status: accepted
- Date: 2026-10-07
- Class: situational. Supersede this record when the player changes its stall, restart or chime rules.
- Related:
  - [ADR 0017](0017-stations-with-alternate-stream.md) §The fallback: this record replaces its failure rule for a stream that played.
  - [ADR 0020](0020-stream-quality-and-hls-live-offset.md): the HLS live offset gives a buffer of about 30 seconds.
  - [ADR 0014](0014-player-screen-with-boost-button.md): the player screen.
  - [ADR 0006](0006-audio-session-off-main-thread.md): blocking work stays off the main thread.
- Task: [stall task 001](../tasks/stall-task-001-stall-budget-and-chime.md)

## Context

On 2026-10-07 the operator reported a problem on Icecast with a bad mobile connection. The chime played for many seconds, and sometimes playback stopped with a timeout.

The causes in `RadioPlayer`:

- A stall sets the state to `connecting`. The chime plays in each `connecting` state, so it plays during each stall, also a short one.
- `automaticallyWaitsToMinimizeStalling` makes AVPlayer wait until it has enough audio. So a stall lasts longer than the network problem.
- A stall starts the connection time limit of 20 seconds. At the end of the limit the stream fails. It fails also when the iPhone has no network path, and the problem is only for a short time.
- A network loss often makes the Icecast player item fail. The app then stops at once, or starts the alternate stream of ADR 0017, which also has no network.

The app has a `NetworkPathMonitor`, but only the relay clients use it.

## Decision

### Two phases

- **Start**: from **Play**, or from a fallback, until the stream plays for the first time. The rules of today apply: the chime plays, and the connection time limit is 20 seconds.
- **Played**: after the stream played for the first time. The rules below apply. A new **Play**, Stop or a fallback starts a new start phase.

### The stall budget

- In the played phase, a stall, a player item failure and an end of the stream are each a drop.
- A drop starts a stall budget of 60 seconds. The budget counts only the seconds while the network path is satisfied. With no path, the app waits for the network and does not fail.
- **Item failure or stream end in the played phase:** the app makes a new player item for the same stream. It waits until the network path is satisfied, then starts the item. The same budget continues. It does not start the alternate stream.
- **A stall with a network:** a stall that lasts 4 seconds while the path is satisfied also gets a new item for the same stream. While the stall continues, the app makes a new item each 5 seconds. Added 2026-10-07: on HLS, after a network gap of 15 seconds, AVPlayer played the buffer to its end and did not load again, with no item failure.
- In one drop, a new item starts a minimum of 5 seconds after the new item before it. So a stream that fails at once does not get many requests each second. The first new item of a drop starts at once.
- When the stream plays again, the budget ends. The next drop starts a new budget.
- When the budget ends with no playback, the failure path of ADR 0017 applies: the alternate stream, if there is one, else the error.
- When the network path becomes satisfied during a stall, the app calls `play()` on the player at once.

### The chime

- In the start phase, the chime plays as now.
- In the played phase, the chime plays only after a drop lasts 3 seconds. A shorter drop is silent.

### The status

- During a drop with no network path, the player screen shows "Waiting for the network".
- During a drop with a network path, it shows "Connecting", as now.

### Not changed

- `automaticallyWaitsToMinimizeStalling` stays true. A resume with less audio gives more short stops on a bad network.
- The reconnect of AVPlayer for Icecast stays, with its repeated audio (ADR 0014).

## Alternatives considered

- **A longer time limit for each stall, with no network check.** A long loss of the network still stops the stream, and a dead stream with a network takes longer to fail.
- **Never fail in the played phase.** A stream that stopped on the server then never gives an error.
- **`automaticallyWaitsToMinimizeStalling` false.** Shorter silences, but more stops and starts on a weak link.

## Consequences

- A short loss of the network gives a silence with no chime, and playback continues.
- A long loss of the network does not stop the app. It plays again when the network returns.
- A stream that is dead on the server fails after 60 seconds of network, not after 20.
- The fallback of ADR 0017 occurs only when the primary stream does not play with a network.

## Invariants

These rules apply while this decision is current.

- The stall budget counts only the seconds with a satisfied path, and ends at 60. `StallBudgetTests` enforces it.
- The chime rule for each phase and the 3 seconds. `ChimeSettingTests` enforces it.
- The status text with no network path. `PlayerScreenModelTests` enforces it.
- The phases, and the call to `play()` at a path change. The new item for the same stream after a drop, also after a stall of 4 seconds with a network. Manual check: examine `RadioPlayer`.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- On Icecast, flight mode on for 10 seconds, then off: no chime for the first 3 seconds, then the chime, and playback continues with no error.
- Flight mode on for 2 minutes: the screen shows "Waiting for the network", and playback continues after flight mode is off.
- A stream that stops on the server while the iPhone has a network fails, or starts the alternate stream, after about 60 seconds.
- A drop of less than 3 seconds gives no chime.
