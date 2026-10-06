# Auto-boost: phase plan

- Status: active, 2026-10-06. This plan does not make rules. [ADR 0013](../adr/0013-boosts.md) owns them. Tasks 001 to 006 implemented the archived [ADR 0012](../archive/adr/0012-auto-boost.md).
- Review: [auto-boost review checklist](../reviews/auto-boost-review-checklist.md).

## Goal

The listener hears a V4V track from its start to its end. Then the app pays one boost of the set amount to the recipients of that track, through the NWC wallet.
The listener can also send a boost with a message to the track that plays, and see the result of each boost in a history.

## Non-goals

- No streaming payments for each minute.
- No change to the relay or to the publisher.
- No boost history outside the phone.

## Assumptions

- The wallet supports `pay_keysend` and `pay_invoice`. Alby Hub supports both.
- The ICY sync of ADR 0011 works on the device. Its visual checks are open.
- The payload title is equal to the display title for the same track, because one producer writes both.

## Affected modules

| Module | Change |
|---|---|
| `CitizenRadioCore` | Tasks 001 to 006: `LiveValuePayload`, `BoostPairing`, `BoostTrigger`, `BoostSettings`, `BoostSplit`, `BoostRecord`, `BoostPlan`, `Bolt11`, `LightningAddress`, `BoostPayer`, `BoostStatusText`, and payments in `NWCClient`. Tasks 007 to 009: the exact amount and the texts in `BoostSettings`, `BoostSender`, `BoostHistory`, the manual decision and the part results. |
| App target | `BoostModel`, the value client in `TrackInfoModel`, the Wallet section items. Task 010: `BoostSheet`, `BoostHistoryView` and the **Boost** button. |
| Documents | ADR 0013 and ADR 0014. Task 011: the architecture overview, the README and the runbook. |

## Sequence

| Task | Wave | Model | Depends on |
|---|---|---|---|
| [001: Live value and pairing](../tasks/auto-boost-task-001-live-value.md) | 1 | Sonnet | none |
| [002: Trigger and settings](../tasks/auto-boost-task-002-trigger.md) | 1 | Sonnet | none |
| [004: NWC payments](../tasks/auto-boost-task-004-nwc-payments.md) | 1 | Opus | none |
| [003: Split, record, BOLT11 and LNURL rules](../tasks/auto-boost-task-003-split-and-record.md) | 2 | Opus | 001, 004 |
| [005: Boost payer](../tasks/auto-boost-task-005-boost-payer.md) | 3 | Opus | 001, 003, 004 |
| [006: Integration and settings view](../tasks/auto-boost-task-006-integration.md) | 4 | Opus | 001 to 005 |
| [007: Boost settings](../tasks/auto-boost-task-007-boost-settings.md) | A | Sonnet | 006 |
| [008: Boost history core](../tasks/auto-boost-task-008-boost-history.md) | A | Sonnet | 006 |
| [009: Message, names, manual decision and part results](../tasks/auto-boost-task-009-message-and-manual.md) | B | Opus | 007, 008 |
| [010: Manual boost, history writes and history screen](../tasks/auto-boost-task-010-manual-boost-and-history.md) | C | Opus | 007 to 009 |
| [011: Xcode project and documents](../tasks/auto-boost-task-011-xcode-and-docs.md) | D | Sonnet | 010 |

Tasks 001 to 006 are complete. Tasks in the same wave change different files, so they can run at the same time.

## API implications

- `TrackDisplay` gets an optional `value: ValueIdentity?`. The existing initializer keeps working with a default of nil.
- `RelayEvent` gets `remoteValueURL` and `valueEventsURL`.
- `NWCClient` gets `pay(_:)`. `getInfo()` does not change.
- The app reads a second SSE stream, `/events`, with the event name `remoteValue`, through the existing `EventStreamClient`.

## Risks

| Risk | Control |
|---|---|
| A payment to the wrong recipient | The placeholder rules, the title pairing, and the block ID when relay ADR 0005 is deployed. Tests for each rule. |
| A double payment | One payment for each `blockGuid` in a session. The repeat rule of the trigger. |
| Too much spending | The daily limit before each boost, and the wallet budget. |
| An invoice for a different amount | The BOLT11 amount check before `pay_invoice`. |
| A payment while the phone is locked fails | The secret uses `kSecAttrAccessibleAfterFirstUnlock` (ADR 0007). A visual check. |
| Work on the main thread | Payments, LNURL requests and the Keychain read run in actors. |

## Test strategy

- Each core rule has Linux tests with fixed values. Tests do not repeat the calculation of the code.
- `NWCClient` payments use the fake relay of the existing NWC tests.
- `BoostPayer` uses a fake wallet and a fake HTTP fetcher.
- The device checks of ADR 0013 cover the real wallet and the real relay.

## Rollback

Revert the commit of task 006. The app then makes no boost. The core types can stay, because nothing else uses them.
