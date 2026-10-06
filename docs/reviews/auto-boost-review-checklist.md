# Auto-boost review checklist

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md).
- Decision: [ADR 0013](../adr/0013-boosts.md). This checklist does not make rules.
- The general items of the [relay display review checklist](relay-display-review-checklist.md) also apply: scope, threading, module boundaries, SwiftUI, privacy and documents.

Use this checklist for the diff of each task. Give one result: pass, or fail with the required fixes.

## Money

- [ ] The placeholder block can never be paid: its title, its `.invalid` host, and each other reserved host.
- [ ] Only a payable destination gets a part. A node key has exactly 66 hex characters.
- [ ] The sum of the parts is never more than the boost amount.
- [ ] The daily limit check comes before the first part. The paid sats and the sats with an unknown result are recorded after the payment.
- [ ] A block is added to the paid set before its payment starts. One block is paid a maximum of one time in a session.
- [ ] An invoice is paid only when its BOLT11 amount equals the requested amount.
- [ ] LNURL uses `https` only.
- [ ] A failed part is not retried.

## Rules

- [ ] The trigger agrees with each rule of ADR 0013 §The trigger, also the repeat rule.
- [ ] The pairing prefers `value.blockGuid`, and does not fall back to the title when the block ID is present.

## Privacy and threading

- [ ] No log contains the secret, a key, an invoice, a title or a comment.
- [ ] The Keychain read, NWC requests and LNURL requests do not run on the main actor.

## Tests

- [ ] Each mechanical criterion of the task has a test that fails without the change.
- [ ] Tests use fixed expected values. No test repeats the split, the JSON or the BOLT11 calculation.
- [ ] `PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh` passes. The reviewer runs it again.

## Result

Return:

1. pass or fail
2. required fixes
3. optional improvements
4. if the task can be committed
5. if the next task packet needs a change
