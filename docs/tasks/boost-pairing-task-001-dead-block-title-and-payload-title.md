# Boost pairing task 001: The dead block title and the payload title

- Decision: [ADR 0026](../adr/0026-dead-block-title-and-artist-title-payload.md). It changes
  [ADR 0013](../adr/0013-boosts.md). The source is publisher ADR 0029 (commit `f8c5792` in
  `~/build/musicindex-live-publisher`).
- Operator choices (2026-11-24, relayed by the orchestrator session): the dead block title is a station setting, and
  the payload title of a payable block is "artist - title".

## Goal

The app does not pay a dead block, also with a station title. The title pairing finds a payload with the title
"artist - title".

## Files to inspect

- `CitizenRadio/Core/LiveValue.swift`, `CitizenRadio/Core/BoostPairing.swift`, `CitizenRadio/Core/BoostPlan.swift`,
  `CitizenRadio/BoostModel.swift`
- `Tests/CitizenRadioCoreTests/LiveValueTests.swift`, `Tests/CitizenRadioCoreTests/BoostPairingTests.swift`

## Files to change

- `CitizenRadio/Core/BoostPairing.swift`: compare the payload title with the key of the track first, then with its
  title.
- `CitizenRadio/Core/LiveValue.swift`: the comment of `isPayable`.
- `Tests/CitizenRadioCoreTests/LiveValueTests.swift`, `Tests/CitizenRadioCoreTests/BoostPairingTests.swift`: new tests.
- `docs/adr/0026-dead-block-title-and-artist-title-payload.md` (new), `docs/adr/0013-boosts.md`,
  `docs/adr/README.md`, `AGENTS.md`.

## Do not touch

- The fix at `TrackInfoModel.swift:438`. It waits for the operator.
- The `blockGuid` pairing and the reserved host list.

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| Boost pairing | extend | CitizenRadio/Core/BoostPairing.swift | The title pairing compares one more text. |
| ICY key | reuse | CitizenRadio/Core/IcySync.swift | `IcySync.key(of:)` gives the song line or "artist - title". |
| Payable check | reuse | CitizenRadio/Core/LiveValue.swift | The reserved host rule drops the dead block destination. |

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes.
- `LiveValueTests`: a dead block with the title "HeyCitizen Test Stream" has no destination and is not payable.
- `BoostPairingTests`: that dead block does not pair by title, by key or by `blockGuid`.
- `BoostPairingTests`: the payload "Anni Powell - Beyond the Hills" pairs with the track "Anni Powell" and
  "Beyond the Hills", and with a track that has that song line. The key wins over the title.
- Each path that pays gets its payload from `BoostPairing.payload(for:)`. Method: read `BoostPlan.decide` and
  `BoostPlan.decideManual`. The **Boost** button target also uses it (`BoostModel.swift:127`).

Visual (open until the operator does the check):

- During a jingle with a station title, the **Boost** button stays gray.
- During a V4V song, the **Boost** button becomes active.
