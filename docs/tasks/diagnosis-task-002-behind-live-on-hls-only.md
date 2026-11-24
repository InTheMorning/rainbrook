# Diagnosis task 002: The "behind live" value only on HLS live

- Decision: [ADR 0022](../adr/0022-playback-log-and-artwork-retry.md) (the playback log).
- Operator choice (2026-11-24, relayed by the orchestrator session): `logPosition` writes a "behind live" number only
  when `item.duration` is indefinite (HLS live). Else it writes "none". This is a defect correction. It needs no new
  ADR.

## Defect

On the progressive stream `radio.mp3`, the log wrote "behind live 44739.2 s". That value is 2^30 bytes divided by
24000 bytes each second. The seekable range of a progressive stream is a byte count estimate, not a live edge. The
value has no effect on playback, but it makes the log incorrect.

## Files to change

- `CitizenRadio/RadioPlayer.swift`: `logPosition`.

## Do not touch

- The buffered value and the other fields of the log line.
- The HLS live offset (ADR 0020).

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| Playback log | reuse | CitizenRadio/RadioPlayer.swift | `logPosition` stays the only function that writes the position line. |

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes.
- `logPosition` calculates "behind live" only when `item.duration.isIndefinite` is true, and else writes "none".
  Method: read the diff. A test cannot examine AVFoundation types on Linux.

Visual (open until the operator does the check):

- On `radio.mp3`, the log lines have "behind live none".
- On `live.m3u8`, the log lines have "behind live" with a number of seconds.
