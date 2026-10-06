# Auto-boost: phase plan

- Status: active, 2026-10-06. This plan does not make rules. [ADR 0012](../adr/0012-auto-boost.md) owns them.
- Review: [auto-boost review checklist](../reviews/auto-boost-review-checklist.md).

## Goal

The listener hears a V4V track from its start to its end. Then the app pays one boost of the set amount to the recipients of that track, through the NWC wallet.

## Non-goals

- No streaming payments for each minute.
- No boost button and no boost message from the listener.
- No change to the relay or to the publisher.
- No boost history in the app. The wallet keeps the payments.

## Assumptions

- The wallet supports `pay_keysend` and `pay_invoice`. Alby Hub supports both.
- The ICY sync of ADR 0011 works on the device. Its visual checks are open.
- The payload title is equal to the display title for the same track, because one producer writes both.

## Affected modules

| Module | Change |
|---|---|
| `CitizenRadioCore` | New: `LiveValuePayload`, `BoostPairing`, `BoostTrigger`, `BoostSettings`, `BoostSplit`, `BoostRecord`, `BoostPlan`, `Bolt11`, `LightningAddress`, `BoostPayer`. Changed: `TrackDisplay` (optional `value`), `RelayEvent` (value routes), `NWCClient` (payments). |
| App target | New: `BoostModel`. Changed: `TrackInfoModel` (sends the ICY texts and tracks to `BoostModel`), `WalletSettingsView` and `WalletSettingsModel` (the two settings and the last result). |
| Documents | The architecture overview, the README and the runbook. |

## Sequence

| Task | Wave | Model | Depends on |
|---|---|---|---|
| [001: Live value and pairing](../tasks/auto-boost-task-001-live-value.md) | 1 | Sonnet | none |
| [002: Trigger and settings](../tasks/auto-boost-task-002-trigger.md) | 1 | Sonnet | none |
| [004: NWC payments](../tasks/auto-boost-task-004-nwc-payments.md) | 1 | Opus | none |
| [003: Split, record, BOLT11 and LNURL rules](../tasks/auto-boost-task-003-split-and-record.md) | 2 | Opus | 001, 004 |
| [005: Boost payer](../tasks/auto-boost-task-005-boost-payer.md) | 3 | Opus | 001, 003, 004 |
| [006: Integration and settings view](../tasks/auto-boost-task-006-integration.md) | 4 | Opus | 001 to 005 |
| [007: Xcode project and documents](../tasks/auto-boost-task-007-xcode-and-docs.md) | 5 | Sonnet | 006 |

Tasks in the same wave change different files, so they can run at the same time.

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
- The device checks of ADR 0012 cover the real wallet and the real relay.

## Rollback

Revert the commit of task 006. The app then makes no boost. The core types can stay, because nothing else uses them.
