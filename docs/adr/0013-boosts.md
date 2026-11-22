# ADR 0013: Boosts

- Status: accepted
- Date: 2026-10-06
- Revised: 2026-11-22. The field **Track info** has the shown word **Live value address** (musicindex `docs/glossary.md` at `b6cdb6a`). The orchestrator session relayed the operator choice.
- Changed by: [ADR 0024](0024-song-line-is-the-icy-key.md)
- Class: situational. Supersede this record when the app pays by a different trigger, by a different method, or from a different value source.
- Supersedes: [ADR 0012](../archive/adr/0012-auto-boost.md)
- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md)
- Related:
  - [ADR 0007](0007-nwc-wallet-configuration.md): the wallet connection, the secret and the daily limit.
  - [ADR 0011](0011-icy-sync-of-the-relay-display.md): the ICY text tells when the listener hears a track.
  - [ADR 0014](0014-player-screen-with-boost-button.md): the player screen and its Boost button.
  - [ADR 0016](0016-boost-switch-back-play-time-and-retry.md): replaces trigger rule 5 and the rule that the app does not retry. It adds the minimum play time, the failure reasons and the retry.

## Context

ADR 0012 added auto-boost: one boost of a set amount when the listener hears a V4V track from its start to its end. Its tasks 001 to 006 are implemented.

On 2026-10-06 the operator asked for four more items:

- An exact boost amount, not only preset values.
- A manual boost with a boostagram message, in addition to auto-boost.
- Settings for the auto-boost message, the sender name and the app name.
- A list of the boosts with the result of each payment.

ADR 0012 made these items non-goals, so this record supersedes it. It restates ADR 0012 and adds the four items.

Facts on 2026-10-06:

- The relay sends the live value on `GET /v1/liveitems/{id}/remoteValue` and on the SSE route `/v1/liveitems/{id}/events`, with the event name `remoteValue`. The data is one payload. [ADR 0018](0018-instant-snapshots-and-replay-on-connect.md) replaces the snapshot source: the app reads `GET /metadata`, not `GET /remoteValue`.
- A V4V payload has `title`, `eventGuid`, `blockGuid`, optional `feedGuid`, `itemGuid` and `duration`, and `value.model.method = keysend`. Each destination has `type`, `address`, `split`, and optional `name`, `customKey`, `customValue` and `fee`.
- Between V4V tracks, the payload is a placeholder: the title "No V4V track playing" and one `lnaddress` destination `no-v4v-track@example.invalid`.
- The display state does not name its payload yet. Relay ADR 0005 and publisher ADR 0012 propose `value {eventGuid, blockGuid}` in the display track.

## Decision

### Settings

The Wallet section of the settings sheet has these boost items. They are active only when a wallet is connected:

- **Auto-boost**: on or off. The default is off.
- **Boost amount**: a whole number of sats from 1 to 100,000. The default is 100. Auto-boost pays this amount. A manual boost starts with this amount.
- **Boost message**: the message of each auto-boost. A maximum of 200 characters. The default is empty.
- **From**: the sender name in each boost. A maximum of 64 characters. The default is empty.
- **App name**: the app name in each boost. A maximum of 64 characters. The default is "CitizenRadio". An empty value gives the default.
- **Boost history**: a link to the history screen.
- The result of the last boost.

**Save** applies the settings, with the other settings of the sheet. **Save** is not possible while the amount is not a whole number from 1 to 100,000.

### The trigger

`BoostTrigger` in `CitizenRadioCore` decides when the listener heard a track from its start to its end. Its inputs are the ICY texts of the session (ADR 0011) and the end of the session.

1. The first ICY text of a session starts no candidate, because the listener joined in the middle of that track.
2. A change of the ICY text to a non-empty text T starts a candidate for T. The text before T is P.
3. While a candidate runs, the trigger keeps the newest relay track that ICY sync selected for T.
4. A change of the ICY text from T to a text that is not T and not P completes the candidate. An empty text also completes it.
5. A change of the ICY text from T back to P drops the candidate. This is the reconnect repeat of ADR 0014: the listener hears the end of P again. [ADR 0016](0016-boost-switch-back-play-time-and-retry.md) §The switch back replaces this rule.
6. The end of the session drops the candidate: Stop, a playback error, or a change of the **Live value address**.
7. A stall or a reconnect with no change of the ICY text does not change the candidate.
8. [ADR 0024](0024-song-line-is-the-icy-key.md) §The chapter change adds a chapter change of an episode file. It
   completes a candidate and starts a new one with no change of the ICY text.

### Manual boost

- The player screen has a **Boost** button (ADR 0014). It is active when the relay track that ICY sync shows now has a payable payload.
- The button opens a boost sheet with the amount, from **Boost amount**, and an empty message. The listener can change both, then tap **Send**.
- A manual boost pays the payload of the track that the listener hears when the sheet opens.
- The sheet shows the split before **Send**: each recipient with its sats for the amount that the sheet shows. The split of §The split applies. A recipient with less than 1 sat does not show.
- The app shows the result in the sheet, and adds it to the history.
- After the boost, the sheet shows **Payment details**, a link to the history entry of that boost. **Close** in the toolbar closes the sheet.
- A manual boost does not use the trigger and does not use the paid block set of auto-boost.

### The pairing

`BoostPairing` in `CitizenRadioCore` selects the payload to pay for a relay track.

- The app keeps the last 8 payloads of the session, newest first, without a duplicate `blockGuid`.
- If the relay track has `value.blockGuid`, the app pays only the payload with that `blockGuid`. If the app does not hold it, there is no boost.
- Else the app pays the newest payload whose `title` is equal to the title of the relay track, after the normalization of ADR 0011 §Matching.
- No relay track gives no boost. A payload with no payable destination gives no boost.

`TrackDisplay` decodes the optional `value {eventGuid, blockGuid}` of a display track. A display track without it is valid.

### Payable destinations

- A destination with `type` equal to `node` is a keysend destination. Its `address` must be 66 hexadecimal characters.
- A destination with `type` equal to `lnaddress` is a lightning address destination. Its `address` must have the form `name@host`.
- The app never pays a lightning address whose host ends in `.invalid`, `.example`, `.test` or `.localhost`, or is `example.com`, `example.net` or `example.org`. This excludes the placeholder.
- The app never pays a payload with the title "No V4V track playing".
- The app ignores a destination of a different type and a destination without a valid split. A JSON boolean is not a valid split.

### The split

`BoostSplit` in `CitizenRadioCore` divides the boost amount, in millisats, among the payable destinations:

1. Each destination with `fee` equal to true gets its `split` as a percentage of the amount.
2. The other destinations share the remaining amount in proportion to their `split` values.
3. Each part is rounded down to whole sats. A part of less than 1 sat is not paid.
4. The sum of the parts is never more than the amount.

### The payment

The app pays each part in sequence over one NWC connection:

- **Keysend:** NWC `pay_keysend` with `amount` in millisats, `pubkey` equal to the address, and `tlv_records`:
  - Type `7629169`: the boost record, a JSON object in UTF-8 with `action: "boost"`, `app_name` (the **App name** setting), `value_msat_total`, `value_msat`, `name` (the destination name), `episode` (the payload title), `guid` (`feedGuid`), `episode_guid` (`itemGuid`), `event_guid`, `block_guid`, `message` and `sender_name`. A key with no value or an empty text is left out.
  - The destination `customKey` with its `customValue` in UTF-8, if both are present and the key is a decimal number.
- [ADR 0023](0023-boost-metadata-for-each-recipient.md) adds `podcast`, `uuid` and the action `auto` to the boost record. It pays a lightning address by keysend first, and adds the LUD-18 name to an LNURL invoice.
- **Lightning address:** LNURL-pay (LUD-16 and LUD-06):
  1. `GET https://host/.well-known/lnurlp/name`. Only `https`.
  2. The answer must have `tag: "payRequest"`, and the amount must be between `minSendable` and `maxSendable`.
  3. `GET` the `callback` with `amount` in millisats. If `commentAllowed` is more than 0, add a comment, cut to that length. The comment is the boost message. With no message, it is "Boost from" and the app name.
  4. The invoice amount must be equal to the requested amount. Else the app does not pay it.
  5. NWC `pay_invoice` with the invoice.
- The message is the **Boost message** setting for an auto-boost, and the text in the boost sheet for a manual boost.
- The wallet must list `pay_keysend` for a keysend part and `pay_invoice` for a lightning address part. Else that part is not paid.
- Each NWC request has a time limit of 30 seconds. Each LNURL request has a time limit of 15 seconds.
- A failure of one part does not stop the other parts. [ADR 0016](0016-boost-switch-back-play-time-and-retry.md) §The retry gives the retry rules.

### The limits

- **Auto-boost:** before the first part, the app checks the full amount against `SpendingLimit` (ADR 0007), together with the amounts of the boosts that are still paying. If it does not fit, there is no auto-boost, and the result says so.
- **Manual boost:** the daily limit does not stop it, because it is an action of the listener. Its sats count against the daily limit.
- After each payment, the app records in `SpendingLimit` the sats of each paid part, and of each part with an unknown result. A part has an unknown result when the wallet did not answer in the time limit, or the connection failed after the request. The wallet can have paid such a part.
- Auto-boost pays each `blockGuid` a maximum of one time in a session.

### The history

`BoostHistory` in `CitizenRadioCore` keeps the last 200 boosts, newest first. The app stores it in a file in its Application Support folder.

- Each entry has: an identifier, the time, auto or manual, the track title and artist, the amount, the message, and one result for each part.
- Each part result has: the recipient name, the type (keysend or lightning address), the sats, and the result: **confirmed**, **failed** or **unknown**.
  - **Confirmed**: the wallet answered with a `result`.
  - **Unknown**: the wallet did not answer in the time limit, or the connection failed after the request.
  - **Failed**: each other result, also an LNURL failure and a part that was not sent.
- A skipped auto-boost gives no entry.
- The **Boost history** screen shows the entries. An entry opens its message and its part results.
- The history stays on the phone. No log contains a title or a message.

### Threading and secrets

- `BoostModel` in the app target is `@MainActor`. It receives the ICY texts, the relay tracks and the payloads, and it starts each boost in a task.
- The Keychain read, the NWC payments, the LNURL requests and the history file read and write run off the main actor (ADR 0006).
- No log contains the secret, an invoice, a title, a message or a comment. The `boost` log category records the amount, the count of parts and the result of each part.

## Alternatives considered

- **Keep ADR 0012 and add a second record.** Two records would own one feature. One record is easier to read and to supersede.
- **Preset amounts only.** The operator wants an exact amount.
- **A manual boost that the daily limit can stop.** A listener who taps **Send** wants to pay. The limit protects against automatic spending.
- **A boost button in Settings only.** More taps while the listener drives.
- **Keep the history in `UserDefaults`.** A file is better for 200 entries with part results.
- **Wait for the block ID of relay ADR 0005.** No title guess, but no boosts until the upstream work is deployed. The pairing prefers the block ID when it is present.

## Consequences

- A track heard from its start to its end gets one auto-boost of the set amount, split among its recipients.
- The listener can boost the track that plays now, with a message, at any time.
- A manual boost can make the total of a day more than the daily limit. Auto-boost then stops for the rest of that day.
- If the same track plays again directly after a different track that was not completed, the trigger can drop it as a repeat. This is a missed auto-boost, never a double payment. ADR 0016 §The switch back makes this smaller.
- Two recent V4V tracks with the same title can make the title pairing pay the newer block. The block ID of relay ADR 0005 removes this risk.
- The history file grows to a maximum of 200 entries.
- A message is not secret. Each recipient and the wallet can see it.

## Invariants

These rules apply while this decision is current.

- The trigger rules. `BoostTriggerTests` enforces them.
- The pairing rules and the payable destination rules. `BoostPairingTests` and `LiveValueTests` enforce them.
- The split rules. `BoostSplitTests` enforces them.
- The boost record keys and the LNURL checks. `BoostRecordTests` and `LightningAddressTests` enforce them.
- The app never pays the placeholder block. `LiveValueTests` enforces it.
- No auto-boost exceeds the daily limit. `BoostPlanTests` enforces it.
- The settings limits: the amount, the message, the sender name and the app name. `BoostSettingsTests` enforces them.
- The history keeps 200 entries and maps each outcome to its result. `BoostHistoryTests` enforces it.
- The secret, the NWC requests, the LNURL requests and the history file stay off the main actor. Manual check: examine `BoostModel`, `BoostPayer` and the history store.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- With **Auto-boost** on, a V4V track heard from its start to its end gives one boost. The wallet shows the payments, and the history shows the entry.
- A V4V track joined in the middle gives no auto-boost.
- A track that is not V4V gives no auto-boost, and the **Boost** button is not active.
- With **Auto-boost** off, no auto-boost occurs.
- An auto-boost over the remaining daily limit does not occur, and the result says why.
- An auto-boost occurs also while the iPhone is locked.
- A manual boost with a message pays the track that plays. A recipient sees the message and the sender name.
- The history shows each recipient with **confirmed**, **failed** or **unknown**.
- The boost sheet shows the split for the amount, and it changes when the amount changes.
- After a manual boost, **Payment details** opens the history entry of that boost.
