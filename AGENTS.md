# citizenradio Agent Guidelines

## The Project

CitizenRadio is an iPhone app in Swift. It plays an Icecast or HLS radio station. It shows the track from a
MusicIndex relay or from the ICY title. It pays boosts through a Nostr Wallet Connect wallet. Only the operator uses
the app.

The app is also the base and the example for a client app of the suite. Write code for reuse in
`CitizenRadio/Core/`. The `project-baseline` skill, section "citizenradio Is The Example Client App", owns this rule.

`README.md` gives the install steps. `docs/architecture/overview.md` gives the data flow and the components.

## The Present Work

- `docs/adr/` holds the current decisions of this app. `docs/archive/adr/` holds the superseded decisions.
- The app reads relay events and ICY titles (`CitizenRadio/Core/LiveValue.swift`, `TrackDisplay.swift`,
  `IcyTitle.swift`). It reads no feed and no file tags.
- The app reads the relay `fee` as a JSON boolean (`LiveValue.swift:146`).
- ADR 0007 and ADR 0014 have open visual acceptance criteria.
- `docs/reviews/2026-11-22-shown-words-and-the-glossary.md` lists the shown words and their glossary rows. Its four
  conflicts and its words with no row wait for the operator and the website session. Its last section names a risk
  for a station that plays an episode file with chapters. No test examines that risk.

## The Design Rules

- `CitizenRadio/Core/` has no SwiftUI, AVFoundation or UIKit import. The host tests run it on Linux. The app files
  that use Apple frameworks are in `CitizenRadio/`. ADR 0005 owns the Swift 6 language mode and the check script.
- A Swift app cannot use a Rust crate. The owner of a shared rule states what applies to this app (`project-baseline`
  skill).
- musicindex ADR 0086 R-FEED-5 applies to this app and to each client app that starts from it:
  - Items 2 to 4 do not apply yet, because the app reads no feed and no tags.
  - When the app starts to read a feed, it accepts the two namespace URIs of musicindex ADR 0086 R-FEED-3. It reads
    `fee` as musicindex ADR 0086 R-FEED-4 item 5 gives.
  - When the app starts to read tags, it reads only the frame names of musicindex ADR 0086 R-TAG-2.
  - The change that adds the read code adds a Swift test for each of these rules that the app uses.
- musicindex ADR 0087 R-WORD-12 item 2 applies to this app and to each client app that starts from it. The app cites
  `~/build/musicindex/docs/glossary.md` for each word that it shows for feed data or value data. The app keeps no word
  list of its own. A new shown word gets a glossary row before it ships (musicindex ADR 0087 R-WORD-13). Ask the
  website session for the row.

## The Working Rules

- Load the `project-baseline` skill before a change. It gives the commit rules and the documentation rules.
- Write prose in Simplified Technical English (`~/.agents/skills/asd-ste100/SKILL.md`).
- The gate is `scripts/check.sh` (ADR 0005). It must pass before a commit. It needs `swift`, `xtool` and `llvm-nm`
  on the `PATH`.
- After a change to `CitizenRadio/RadioIntents.swift`, run `scripts/generate-app-intents-metadata.sh` on a Mac with
  Xcode, and commit the result (ADR 0003).
- Do not add a license file. The operator chose no license on 2026-11-22 (`project-baseline` skill).
- The operator does each push.
