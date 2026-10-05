# ICY sync review checklist

- Plan: [ICY sync phase plan](../plans/icy-sync-plan.md).
- Decision: [ADR 0011](../adr/0011-icy-sync-of-the-relay-display.md). This checklist does not make rules.
- The general items of the [relay display review checklist](relay-display-review-checklist.md) also apply: scope, threading, module boundaries, SwiftUI, privacy and documents.

Use this checklist for the diff of each task. Give one result: pass, or fail with the required fixes.

## Rules

- [ ] `IcySync` agrees with each rule of ADR 0011 §The list and the selection and §Matching.
- [ ] The prefix rule needs a minimum of 8 characters and a minimum of one character after the first `" - "`.
- [ ] A group with no `StreamTitle` item does not call `onText`. An empty title calls `onText("")`.
- [ ] With ICY in the session, `TrackInfoModel` schedules no timed apply, and backoff keeps the relay track.
- [ ] Without ICY in the session, the ADR 0008 timed rule is unchanged.
- [ ] A `404` or `409` stop and a change of the event clear the states. Stop makes a new `IcySync`.

## Tests

- [ ] Each mechanical criterion of the task has a test that fails without the change.
- [ ] The tests use fixed texts. No test repeats the normalize or match code to get its expected value.
- [ ] `PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh` passes. The reviewer runs it again.

## Result

Return:

1. pass or fail
2. required fixes
3. optional improvements
4. if the task can be committed
5. if the next task packet needs a change
