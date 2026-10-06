# ADR 0012: Auto-boost

- Status: accepted
- Date: 2026-10-06
- Class: situational. Supersede this record when the app pays by a different trigger, by a different method, or from a different value source.
- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md)
- Related:
  - [ADR 0007](0007-nwc-wallet-configuration.md): the wallet connection, the secret and the daily limit. This record is the payment record that ADR 0007 names.
  - [ADR 0011](0011-icy-sync-of-the-relay-display.md): the ICY text tells when the listener hears a track.
  - [ADR 0010](0010-player-screen-without-extra-buffer.md): the settings sheet.

## Context

The app has a Nostr Wallet Connect (NWC) wallet (ADR 0007). The station relay sends a live value block for each V4V track. The operator wants a new feature. When the listener hears a V4V track from its start to its end, the app boosts the artist by a set amount.

Facts on 2026-10-06:

- The relay sends the live value on `GET /v1/liveitems/{id}/remoteValue` and on the SSE route `/v1/liveitems/{id}/events`, with the event name `remoteValue`. The data is one payload.
- A V4V payload from `musicindex-live-publisher` has `title`, `eventGuid`, `blockGuid`, optional `feedGuid`, `itemGuid` and `duration`, and `value.model.method = keysend`. Each destination has `type`, `address`, `split`, and optional `name`, `customKey`, `customValue` and `fee`.
- Between V4V tracks, the payload is a placeholder: the title "No V4V track playing" and one `lnaddress` destination `no-v4v-track@example.invalid`.
- The display state does not name its payload yet. Relay ADR 0005 and publisher ADR 0012 propose `value {eventGuid, blockGuid}` in the display track. They are not implemented.
- The payload has no artist. Only the title can pair it with a display state now.

## Decision

### Settings

The Wallet section of the settings sheet gets two items:

- **Auto-boost**: on or off. The default is off.
- **Boost amount**: 21, 50, 100, 250, 500 or 1,000 sats for each track. The default is 100 sats.

The items are active only when a wallet is connected. The section also shows the result of the last boost.

### The trigger

`BoostTrigger` in `CitizenRadioCore` decides when the listener heard a track from its start to its end. Its inputs are the ICY texts of the session (ADR 0011) and the end of the session.

1. The first ICY text of a session starts no candidate, because the listener joined in the middle of that track.
2. A change of the ICY text to a non-empty text T starts a candidate for T. The text before T is P.
3. While a candidate runs, the trigger keeps the newest relay track that ICY sync selected for T.
4. A change of the ICY text from T to a text that is not T and not P completes the candidate. An empty text also completes it.
5. A change of the ICY text from T back to P drops the candidate. This is the reconnect repeat of ADR 0010: the listener hears the end of P again.
6. The end of the session drops the candidate: Stop, a playback error, or a change of the **Track info** event.
7. A stall or a reconnect with no change of the ICY text does not change the candidate.

The trigger has no clock. It does not use `duration`.

### The pairing

`BoostPairing` in `CitizenRadioCore` selects the payload to pay for a completed candidate.

- The app keeps the last 8 payloads of the session, newest first, without a duplicate `blockGuid`.
- If the relay track of the candidate has `value.blockGuid`, the app pays only the payload with that `blockGuid`. If the app does not hold it, there is no boost.
- Else the app pays the newest payload whose `title` is equal to the title of the relay track, after the normalization of ADR 0011 §Matching.
- A candidate with no relay track gives no boost.
- A payload with no payable destination gives no boost.

`TrackDisplay` decodes the optional `value {eventGuid, blockGuid}` of a display track. A display track without it is valid.

### Payable destinations

- A destination with `type` equal to `node` is a keysend destination. Its `address` must be 66 hexadecimal characters.
- A destination with `type` equal to `lnaddress` is a lightning address destination. Its `address` must have the form `name@host`.
- The app never pays a lightning address whose host ends in `.invalid`, `.example`, `.test` or `.localhost`, or is `example.com`, `example.net` or `example.org`. This excludes the placeholder.
- The app never pays a payload with the title "No V4V track playing".
- The app ignores a destination of a different type and a destination without a valid split.

### The split

`BoostSplit` in `CitizenRadioCore` divides the boost amount, in millisats, among the payable destinations:

1. Each destination with `fee` equal to true gets its `split` as a percentage of the amount.
2. The other destinations share the remaining amount in proportion to their `split` values.
3. Each part is rounded down to whole sats. A part of less than 1 sat is not paid.
4. The sum of the parts is never more than the amount.

### The payment

The app pays each part in sequence over one NWC connection:

- **Keysend:** NWC `pay_keysend` with `amount` in millisats, `pubkey` equal to the address, and `tlv_records`:
  - Type `7629169`: the boost record, a JSON object in UTF-8 with `action: "boost"`, `app_name: "CitizenRadio"`, `value_msat_total`, `value_msat`, `name` (the destination name), `episode` (the payload title), `guid` (`feedGuid`), `episode_guid` (`itemGuid`), `event_guid` and `block_guid`. A key with no value is left out.
  - The destination `customKey` with its `customValue` in UTF-8, if both are present and the key is a decimal number.
- **Lightning address:** LNURL-pay (LUD-16 and LUD-06):
  1. `GET https://host/.well-known/lnurlp/name`. Only `https`.
  2. The answer must have `tag: "payRequest"`, and the amount must be between `minSendable` and `maxSendable`.
  3. `GET` the `callback` with `amount` in millisats. If `commentAllowed` is more than 0, add a comment "Boost from CitizenRadio", cut to that length.
  4. The invoice amount must be equal to the requested amount. Else the app does not pay it.
  5. NWC `pay_invoice` with the invoice.
- The wallet must list `pay_keysend` for a keysend part and `pay_invoice` for a lightning address part. Else that part is not paid.
- Each NWC request has a time limit of 30 seconds. Each LNURL request has a time limit of 15 seconds.
- The app does not retry a failed part. A failure of one part does not stop the other parts.

### The limits

- Before the first part, the app checks the full boost amount against `SpendingLimit` (ADR 0007). If it does not fit, there is no boost, and the result says so.
- After the payment, the app records in `SpendingLimit` the sats of each paid part, and of each part with an unknown result. A part has an unknown result when the wallet did not answer in the time limit, or the connection failed after the request. The wallet can have paid such a part, so it counts against the limit.
- The app pays each `blockGuid` a maximum of one time in a session.

### Threading and secrets

- `BoostModel` in the app target is `@MainActor`. It receives the ICY texts, the relay tracks and the payloads, and it starts each boost in a task.
- The Keychain read of the secret, the NWC payments and the LNURL requests run off the main actor (ADR 0006).
- No log contains the secret, an invoice, a title or a comment. The `boost` log category records the amount, the count of parts and the result of each part.

## Alternatives considered

- **Wait for the block ID of relay ADR 0005.** No title guess, but no boosts until the upstream work is deployed. The pairing already prefers the block ID when it is present.
- **Most of the duration.** Needs `duration`, which is optional, and a clock. The ICY changes already mark the start and the end.
- **Keysend only.** Simpler, but a track with only lightning address destinations would get no boost.
- **Streaming payments for each minute.** A different feature. This record pays one boost for each complete track.

## Consequences

- A track heard from its start to its end gets one boost of the set amount, split among its recipients.
- A track that the listener joins in the middle gets no boost.
- If the same track plays again directly after a different track that was not completed, the trigger can drop it as a repeat. The app then does not pay. This is a missed boost, never a double payment.
- Two recent V4V tracks with the same title can make the title pairing pay the newer block. The block ID of relay ADR 0005 removes this risk.
- Each boost opens one NWC connection. A boost with lightning address parts also makes 2 HTTPS requests for each such part.
- Spending happens without a confirmation. The daily limit and the wallet budget are the protection.

## Invariants

These rules apply while this decision is current.

- The trigger rules. `BoostTriggerTests` enforces them.
- The pairing rules and the payable destination rules. `BoostPairingTests` and `LiveValueTests` enforce them.
- The split rules. `BoostSplitTests` enforces them.
- The boost record keys and the LNURL checks. `BoostRecordTests` and `LightningAddressTests` enforce them.
- The app never pays the placeholder block. `LiveValueTests` enforces it.
- No boost exceeds the daily limit. `BoostPlanTests` enforces it.
- The secret, the NWC requests and the LNURL requests stay off the main actor. Manual check: examine `BoostModel` and `BoostPayer`.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- With **Auto-boost** on, a V4V track heard from its start to its end gives one boost. The wallet shows the payments, and the Wallet section shows the result.
- A V4V track joined in the middle gives no boost.
- A track that is not V4V gives no boost.
- With **Auto-boost** off, no boost occurs.
- A boost over the remaining daily limit does not occur, and the result says why.
- A boost occurs also while the iPhone is locked.
