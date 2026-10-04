# ADR 0003: Committed App Intents metadata

- Status: accepted
- Date: 2026-10-04
- Class: situational. Supersede this record when xtool makes App Intents metadata, or when the app stops using xtool.

## Context

iOS finds App Intents through a `Metadata.appintents` directory in the app bundle.
Xcode makes this directory with `appintentsmetadataprocessor`, a macOS program.
xtool has no replacement for that program ([xtool issue 145](https://github.com/xtool-org/xtool/issues/145)).
The development computer for this app is Linux.

A first proposal copied the metadata into the app after `xtool dev build --sign` and then ran `xtool install`.
`xtool install` signs the app again.
The xtool signer reads the prefixed bundle ID and adds the prefix again (`DeveloperServicesAddAppOperation.upsertApp`).
The xtool source shows that the result is `XTL-<team>.XTL-<team>.<bundleID>` and one more App ID for each install.

## Decision

- The repository contains the metadata that Xcode makes, in `Configuration/AppIntents/Metadata.appintents`.
- `xtool.yml` lists that directory in `resources`. xtool copies it to the bundle root before it signs.
- `xtool dev` builds, signs one time, and installs. No script changes the app after signing.
- The Swift package compiles `CitizenRadio/RadioIntents.swift`.
- After a change to `RadioIntents.swift`, a person runs `scripts/generate-app-intents-metadata.sh` on a Mac with Xcode and commits the result.

## Alternatives considered

- Copy the metadata after signing and install with `xtool install`. This signs two times and changes the bundle ID, as the Context section tells.
- Write the metadata by hand on Linux. The format is undocumented, and the result cannot be tested without a device.
- Use URL actions only. They open the app and can require unlocking, so they cannot start playback from a locked phone.

## Consequences

- Shortcuts reads the actions from `extract.actionsdata`, which contains no bundle ID.
- `root.ssu.yaml` contains `org.citizenradio.CitizenRadio`, but xtool installs the app as `XTL-<team>.org.citizenradio.CitizenRadio`.
  This difference can stop the Siri voice phrases. It is not known if it does.
  If the phrases fail, write the installed bundle ID into `root.ssu.yaml`. The ID is the same for each install from one Apple account.
- A change to the intents without new metadata gives no build error. The actions can then fail on the iPhone.

## Invariants

- `Configuration/AppIntents/Metadata.appintents` agrees with `CitizenRadio/RadioIntents.swift`.
  Manual check: run `scripts/generate-app-intents-metadata.sh` on a Mac after a change to the intents. No test can run the Xcode tool on Linux.
- No step adds files to the app after xtool signs it.
  Manual check: the install procedure is `xtool dev` only. This rule has not broken in a commit, so it has no test.
