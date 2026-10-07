# ADR 0015: Artwork from a URL and animated GIF images

- Status: accepted
- Date: 2026-10-06
- Class: situational. Supersede this record when the artwork source, the image formats or the display of an animation changes.
- Related:
  - [ADR 0008](0008-relay-display-metadata.md) §Artwork: this record replaces its size and type rule for an image from a URL.
  - [ADR 0006](0006-audio-session-off-main-thread.md): blocking work stays off the main thread.
  - [ADR 0014](0014-player-screen-with-boost-button.md): the player screen.
- Task: [artwork task 001](../tasks/artwork-task-001-url-and-gif.md)

## Context

ADR 0008 rejects each image larger than 524,288 bytes, and each type that is not JPEG or PNG.

On 2026-10-06 the track "Nowhere Anywhere" played with no artwork. Its display state had an artwork URL to a PNG of 659,106 bytes, 800 × 800 pixels. The app rejected it because of the size.

The publisher makes each embedded image smaller before it uploads it to the relay. A track with an image URL (`TXXX:MusicIndex Image`) sends that URL unchanged. So the URL images of the station can be large, and some are animated GIF images. "How Bout You?" has a GIF of 33 MB, and "Disco Swag" has a GIF of 5.0 MB.

The operator wants these images to show, also the animation.

## Decision

### Relay images

No change. A relay image (`sha256` and `mime`) must be JPEG or PNG and a maximum of 524,288 bytes.

### Images from a URL

- The formats are JPEG, PNG and GIF. The app finds the format from the first bytes, not from the header or the URL.
  - JPEG starts with `FF D8 FF`. PNG starts with `89 50 4E 47 0D 0A 1A 0A`. GIF starts with `GIF87a` or `GIF89a`.
- The download limit is 41,943,040 bytes (40 MiB).
  - A `Content-Length` larger than the limit stops the download before the body.
  - The app reads the body as a stream, and stops when it gets more bytes than the limit. Then there is no image.

### Decoding

The app decodes with ImageIO, in `ArtworkLoader`, off the main thread.

- **A still image**, and a GIF with one frame: the app makes a thumbnail with a maximum of 1,024 pixels on the longest side. A smaller image keeps its size.
- **An animated GIF**, a GIF with two or more frames:
  - Each frame is made with a maximum of 400 pixels on the longest side.
  - The delay of a frame is its unclamped delay, else its delay. A delay of less than 0.02 seconds becomes 0.1 seconds, as browsers do.
  - The decoded frames together use a maximum of 50,331,648 bytes (48 MiB), at 4 bytes for each pixel.
  - If all frames do not fit, the app keeps frames at regular steps. The delay of a dropped frame goes to the kept frame before it, so the full play time stays the same.
  - The result is an animated image with the kept frames and the total play time.
- A decode failure gives no image, and the placeholder stays.

`ArtworkFrames` in `CitizenRadioCore` makes the frame selection and the delays, with no ImageIO.

### Display

- The player screen animates an animated image, and shows a still image as before.
- Now Playing gets the first frame, because the lock screen and the car show a still image.

### Cache

The memory cache of ADR 0008 does not change: 8 images, keyed by the SHA-256 or the URL.

## Alternatives considered

- **Keep 524,288 bytes for each image.** Large URL images then never show.
- **Ask the publisher to make URL images smaller.** The publisher sends the URL and no file, so the listener app can show the original image and its animation. A change there is outside this app.
- **Show only the first frame of a GIF.** Simpler, but the operator wants the animation.
- **Decode all frames at full size.** A GIF with many large frames can then use hundreds of MB of memory.

## Consequences

- A URL image with a maximum size of 40 MiB can show. It uses network data for each new load. The memory cache keeps the last 8 images, so a track that plays again in the same session does not load its image again.
- A GIF with very many frames plays with fewer frames, at the same speed.
- Now Playing shows the first frame of an animated GIF.

## Invariants

These rules apply while this decision is current.

- The format and size rules for each source. `ArtworkPolicyTests` enforces them.
- The frame selection, the delay rules and the memory limit. `ArtworkFramesTests` enforces them.
- The download stops at the limit, and the decode runs off the main actor. Manual check: examine `ArtworkLoader`.

## Acceptance criteria

### Mechanical

- `ArtworkPolicyTests` and `ArtworkFramesTests` cover each rule above.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- "Nowhere Anywhere" shows its artwork.
- "How Bout You?" shows its GIF, and the GIF moves.
- "Disco Swag" shows its GIF, and the GIF moves.
- The lock screen shows the first frame of a GIF track.
- A track with a relay image shows its artwork as before.
