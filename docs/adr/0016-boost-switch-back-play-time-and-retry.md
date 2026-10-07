# ADR 0016: Boost switch back, minimum play time and retry

- Status: accepted
- Date: 2026-10-06
- Class: situational. Supersede this record when the trigger, the retry rules or the stored part data change.
- Related:
  - [ADR 0013](0013-boosts.md): this record replaces its trigger rule 5 and its rule "The app does not retry a failed part". It adds a setting, a trigger rule, a limit rule and history fields.
  - [ADR 0006](0006-audio-session-off-main-thread.md): blocking work stays off the main thread.
- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), tasks 012 to 014.

## Context

On 2026-10-06 the operator asked about a fast switch between two tracks in Mixxx. Two trigger rules of ADR 0013 then give a result that the operator does not want:

- The trigger has no clock. A track that plays for 5 seconds before the next ICY text gets a full auto-boost.
- A change of the ICY text back to the text before it drops the candidate as a reconnect repeat. A real switch back to the earlier track thus never gets an auto-boost.

On the same day an auto-boost of "Nowhere Anywhere" by Survival Guide failed for its main part. That part is a keysend of 70% to the node `02096c79…d696c4`. The history did not keep the wallet error, so the cause is not known. A keysend usually fails when the node is offline or when the wallet finds no route. A later attempt can succeed.

Facts from the publisher on 2026-10-06 (its configuration runbook, §Replay):

- A new Mixxx history row gives a new play and a new `blockGuid`.
- With the Mixxx default "Track duplicate distance" of 6, a switch back to a track in the other deck gives no new history row. The block of the first play stays.
- With the setting 0, or in the connector mode, each load gives a new history row and a new block. Each change of the playing deck also gives them.
- A reconnect repeat plays the same audio again, so the ICY sync selects the same display state and the same block.

## Decision

### The switch back

This replaces ADR 0013 §The trigger rule 5.

- The trigger gets each ICY text together with the relay track that ICY sync selects for that text.
- The trigger keeps the `blockGuid` of the newest selected track for the present text and for the text before it.
- A change of the ICY text from T back to P, while a candidate for T runs:
  - A switch back has two known blocks that are different: the block of the earlier play of P, and the block of the selected track for the new P. The candidate for T completes, and a new candidate for P starts.
  - Else it is a reconnect repeat. The candidate for T is dropped, as before.

So a switch back gets an auto-boost only when the publisher gives a new block. An unknown block stays a repeat. This can miss an auto-boost, but it never pays twice.

### The minimum play time

- A new setting, **Minimum play time**, in the Wallet section: a whole number of seconds from 0 to 600. The default is 60. The value 0 disables the check.
- The play time of a candidate starts at its ICY text and stops at the ICY text that completes it. The app uses the monotonic clock of the phone. The ICY texts arrive with the audio, so this is the time that the listener heard the track.
- An auto-boost with a play time of less than the setting does not occur. The result says so. The block is not added to the paid blocks, so a later full play of the same block can boost.
- A manual boost does not use this rule.

### The failure reason

Each failed part result keeps its reason:

- **Wallet error**: the NWC error code and message. The app keeps a maximum of 200 characters of the message.
- **Not supported**: the wallet does not list the method.
- **Bad answer**: the wallet answer was not valid.
- **Not sent**: the app sent no request for the part, for example after a connection failure.
- **Lightning address**: an LNURL request or check failed.

The history screen shows the reason of each failed part. No log contains the message.

### The retry

This replaces the ADR 0013 rule "The app does not retry a failed part".

- A failed part is **retryable** when its reason is wallet error, not sent or lightning address. A part with the reason not supported or bad answer is not retryable. A part with the result unknown is never retried, because the wallet can have paid it.
- The history entry keeps the payment data of each retryable part:
  - A keysend part: the node address, the amount and the TLV records. A retry sends the same records, so the recipient gets the same boost.
  - A lightning address part: the name, the host, the amount and the comment. A retry gets a new invoice.
  - The app removes the payment data when the part becomes confirmed, unknown or not retryable.
- **Automatic retry:** after a boost with a retryable part, the app sends the retryable parts again after 1 minute. If a part is still retryable, it sends it again after 10 more minutes. Then it stops. The automatic retry runs only while the app runs. It continues while the iPhone is locked.
- **Manual retry:** the history entry shows a **Retry** button when it has a retryable part and no retry of it runs. A tap sends the retryable parts again.
- A retry sends all retryable parts of one entry over one NWC connection, with the payment rules of ADR 0013 §The payment.
- Only one retry of an entry runs at a time.
- The retry updates the part results of the same entry. It adds no new entry. Each part keeps its count of attempts.

### The limits of a retry

- The app records the paid sats and the unknown sats of a retry in `SpendingLimit`, as for each payment.
- Before an automatic retry of an auto-boost, the app checks the sum of its retryable parts against the daily limit. The amounts that are still paying count. If it does not fit, the app makes no more automatic retries of that entry.
- A manual retry, and an automatic retry of a manual boost, are not stopped by the daily limit. Their sats count.

## Alternatives considered

- **Keep rule 5.** A real switch back then never boosts.
- **Treat each switch back as a new play.** A reconnect repeat then pays the same track again.
- **A fixed minimum play time.** The operator asked for a setting.
- **Retry each failed part.** A wallet that does not support a method fails again. A part with an unknown result can be paid already.
- **Retry with no stored payment data.** A retry after a restart of the app is then not possible.
- **Store the invoice for a retry.** An invoice can expire. A new invoice is safe.

## Consequences

- A track that plays for less than the minimum play time gets no auto-boost.
- A switch back gets an auto-boost only with the Mixxx setting "Track duplicate distance" 0 or with the connector mode. With the default setting, the block of the first play stays, and it is paid already.
- A keysend to a node that is offline for a short time can succeed on a retry.
- A retry can occur after the next track starts. The recipient sees the boost late.
- The history file gets larger: it keeps the TLV records of each retryable part. 200 entries stay small.
- A wallet that answers with an error after it paid can make a retry pay a part two times. NIP-47 gives an error only for a payment that failed, so this is improbable.

## Invariants

These rules apply while this decision is current.

- The switch back rule and the play time. `BoostTriggerTests` enforces them.
- The minimum play time check and its setting limits. `BoostPlanTests` and `BoostSettingsTests` enforce them.
- The retryable rule, the stored payment data and the update of an entry. `BoostHistoryTests` and `BoostPayerTests` enforce them.
- A retry never pays a part with the result unknown. `BoostPayerTests` enforces it.
- The retry schedule, the one retry for each entry, and the limit check of an automatic retry. Manual check: examine `BoostModel`. The schedule uses time in the app target.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- With **Minimum play time** 60, a V4V track played for 20 seconds gives no auto-boost, and the result says why.
- Set "Track duplicate distance" to 0 in Mixxx. Then a switch back to a V4V track gives an auto-boost, if the track plays for the minimum play time.
- A failed part shows its reason in the history.
- A failed keysend part is sent again after about 1 minute, and the history entry shows the new result.
- **Retry** in a history entry sends the failed parts again.
