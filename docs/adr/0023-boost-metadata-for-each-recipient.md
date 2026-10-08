# ADR 0023: Boost metadata for each recipient

- Status: accepted
- Date: 2026-10-07
- Class: situational. Supersede this record when the boost record, the payment path of a lightning address, or the receivers that the app supports change.
- Related:
  - [ADR 0013](0013-boosts.md) §The payment: this record changes the boost record and the payment of a lightning address part.
  - [ADR 0016](0016-boost-switch-back-play-time-and-retry.md): the retry data and the failure reasons.
  - [ADR 0017](0017-stations-with-alternate-stream.md): the station name.
- Task: [boost metadata task 001](../tasks/boost-metadata-task-001-record-and-keysend-first.md)

## Context

On 2026-10-07 the operator asked the app to send correct boost metadata, so that Helipad can read it.

Facts on 2026-10-07:

- **The record of a keysend part** (TLV 7629169, bLIP-10) has `action`, `app_name`, `value_msat`, `value_msat_total`, `name`, `episode`, `guid`, `episode_guid`, `message`, `sender_name`, `event_guid` and `block_guid`.
  - bLIP-10 requires one of `podcast`, `feedID`, `url` or `guid`. The app sends `guid` only when the payload has a `feedGuid`. So a record can have no podcast identifier.
  - bLIP-10 recommends one `uuid` for each boost, the same in each split. The app sends none.
  - The app sends `action: "boost"` also for an auto-boost.
- **Helipad** (`Podcastindex-org/helipad`, `src/boost.rs`) reads these fields of the record: `action`, `app_name`, `message`, `sender_name`, `podcast`, `episode`, `value_msat`, `value_msat_total`, `remote_feed_guid` and `remote_item_guid`.
  - It knows the actions `boost`, `stream` and `auto`, and lists `auto` as a boost.
  - It keeps TLV `696969` as the key of a custodial wallet.
  - For an invoice with no record, it shows the memo as the message, with the sender "Lightning Invoice". A comment `rss::payment::<action> https://<domain>/…` gives a full record only for the domains of its list.
- **A lightning address part** pays an LNURL invoice with a comment: the message, else "Boost from" and the app name. The recipient gets no record and no sender name.
- **Castamatic** pays a lightning address by keysend when the address offers keysend, else by LNURL-pay.
  - Alby gives `https://getalby.com/.well-known/keysend/<name>` with `status`, `tag: "keysend"`, `pubkey` and `customData` (`customKey` `696969` and a `customValue`).
  - `phafe.com` gives no keysend answer.
  - Alby gives this answer for each account. It does not tell if the node accepts keysend. LND accepts keysend only with `accept-keysend=true`.
- LUD-18 lets a payer send `payerdata` with a name, when the `payRequest` lists `payerData.name`. Alby lists it.

## Decision

### The boost record

- `podcast`: the `podcastName` of the payload. If the payload has none, the name of the station that plays.
- `uuid`: one random UUID for each boost, in lowercase text. Each split of the boost has the same value. A retry sends the same record, with the same value.
- `action`: `"auto"` for an auto-boost, `"boost"` for a manual boost.
- The other keys do not change.

### A lightning address part

1. The app reads `https://host/.well-known/keysend/name`, with the time limit of an LNURL request.
2. A correct answer has status 200, `tag` equal to `keysend`, and a `pubkey` of 66 hexadecimal characters. Then the app pays the part by keysend to that key:
   - with the boost record of the part.
   - with each `customData` entry whose `customKey` is a decimal number, as one more TLV record. The value is the `customValue` in UTF-8.
3. Else the app pays the part by LNURL invoice, as ADR 0013 says.
4. The wallet can give a wallet error or "not supported" for the keysend payment. Then the app pays the same part by LNURL invoice, in the same boost. It never does this after an unknown result, and never after a confirmed result.
5. The part result keeps the path that paid it, or that failed last: keysend or invoice.
6. A retry of ADR 0016 does the steps 1 to 4 again for a lightning address part, with the same record.

### The LNURL invoice

- The comment does not change.
- If the `payRequest` lists `payerData.name`, and the **From** setting is not empty, the callback gets `payerdata` with the JSON `{"name": "<From>"}`.

## Alternatives considered

- **Keysend only for a lightning address.** A node that does not accept keysend never gets the payment.
- **Remember a failed keysend for each address.** The operator declined this. Each boost does the steps again.
- **A comment `rss::payment::boost https://…`.** Helipad reads it only for the domains of its list. The app has no server on that list.
- **The record as JSON in the comment.** No standard. Receivers show it as raw text.
- **`guid` and `episode_guid` for the show, and `remote_feed_guid` and `remote_item_guid` for the song.** These keys are not in bLIP-10, and the app does not know the GUID of the show feed. A later record can decide this.

## Consequences

- Helipad shows a boost from the app with the podcast, the track, the sender, the message and the app name. It shows an auto-boost with the action `auto`.
- A recipient on Alby gets the full record by keysend.
- A lightning address part can make one more request. A node that rejects keysend gets one failed keysend before the invoice. Nothing is paid two times.
- The history shows the path of each lightning address part.

## Invariants

These rules apply while this decision is current.

- The record keys `podcast`, `uuid` and `action`, and one `uuid` for all splits. `BoostRecordTests` enforces them.
- The keysend answer rules and the `customData` records. `LightningAddressTests` enforces them.
- The path rules: keysend first, the invoice after a wallet error or "not supported", and no invoice after an unknown result. `BoostPayerTests` enforces them.
- `payerdata` only when the service lists `payerData.name`. `LightningAddressTests` enforces it.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- An old history file with lightning address parts still decodes. `BoostHistoryTests` enforces it.
- `scripts/check.sh` passes.

### Visual

A person must examine these items. Report each item as open until a person completes that check.

- A boost to a recipient with Helipad shows the podcast, the track, the **From** name, the message and "CitizenRadio".
- An auto-boost shows the action `auto` in Helipad.
- A boost to an Alby lightning address arrives as a keysend boost. The history shows the path "keysend".
- A boost to `mattfinlay@phafe.com` arrives by invoice with the comment. The history shows the path "invoice".
