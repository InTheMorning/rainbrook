# Current Decisions

This file is the index of the current decisions of citizenradio. It answers what binds a change today
(`project-baseline` skill, section "A Binding Rule Lives In A Decision Record"). `docs/archive/adr/` holds the
superseded decisions.

The gate `scripts/check.sh` runs `check_adr_links.py` of the `project-baseline` skill with `--bar-from 0024`. Each
ADR from number 0024 has a `- Bar:` line or a `- Supersedes:` line.

| ADR | Title | Status |
| --- | --- | --- |
| [ADR 0003](0003-committed-app-intents-metadata.md) | Committed App Intents metadata | accepted |
| [ADR 0005](0005-swift-6-and-check-script.md) | Swift 6 and the check script | accepted |
| [ADR 0006](0006-audio-session-off-main-thread.md) | Audio session activation off the main thread | accepted |
| [ADR 0007](0007-nwc-wallet-configuration.md) | NWC wallet configuration | accepted. The visual acceptance criteria are open. |
| [ADR 0008](0008-relay-display-metadata.md) | Track metadata and artwork from the relay | accepted |
| [ADR 0011](0011-icy-sync-of-the-relay-display.md) | ICY sync of the relay display | accepted |
| [ADR 0013](0013-boosts.md) | Boosts | accepted |
| [ADR 0014](0014-player-screen-with-boost-button.md) | Player screen with the Boost button | accepted. The visual acceptance criteria are open. |
| [ADR 0015](0015-artwork-from-url-and-animated-gif.md) | Artwork from a URL and animated GIF images | accepted |
| [ADR 0016](0016-boost-switch-back-play-time-and-retry.md) | Boost switch back, minimum play time and retry | accepted |
| [ADR 0017](0017-stations-with-alternate-stream.md) | Stations with an alternate stream | accepted |
| [ADR 0018](0018-instant-snapshots-and-replay-on-connect.md) | Instant snapshots and replay on connect | accepted |
| [ADR 0019](0019-album-in-the-display.md) | The album in the display | accepted |
| [ADR 0020](0020-stream-quality-and-hls-live-offset.md) | Stream quality and the HLS live offset | accepted |
| [ADR 0021](0021-stalls-on-a-bad-network.md) | Stalls on a bad network | accepted |
| [ADR 0022](0022-playback-log-and-artwork-retry.md) | Playback log and artwork retry | accepted |
| [ADR 0023](0023-boost-metadata-for-each-recipient.md) | Boost metadata for each recipient | accepted |
| [ADR 0024](0024-song-line-is-the-icy-key.md) | The song line is the ICY key of a display state | accepted |
| [ADR 0025](0025-the-icy-text-of-an-hls-stream.md) | The ICY text of an HLS stream | accepted |
| [ADR 0026](0026-dead-block-title-and-artist-title-payload.md) | The dead block title and the "artist - title" payload | accepted |
