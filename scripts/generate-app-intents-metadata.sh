#!/usr/bin/env bash
# Regenerates Configuration/AppIntents/Metadata.appintents with Xcode.
# xtool cannot produce this metadata (https://github.com/xtool-org/xtool/issues/145),
# so xtool.yml lists the committed result in `resources` and xtool copies it into the app.
# Run this on a Mac with Xcode after changing RadioIntents.swift, then commit the result.
set -euo pipefail

if ! command -v xcodebuild >/dev/null; then
    echo "error: this script needs a Mac with Xcode. To install on a phone, run xtool dev." >&2
    exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/Configuration/AppIntents/Metadata.appintents"
derived="$(mktemp -d)"
trap 'rm -rf "$derived"' EXIT

echo "Building CitizenRadio with Xcode to extract App Intents metadata..."
xcodebuild \
    -project "$root/CitizenRadio.xcodeproj" \
    -scheme CitizenRadio \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$derived" \
    CODE_SIGNING_ALLOWED=NO \
    build >"$derived/build.log" 2>&1 || {
        tail -40 "$derived/build.log"
        echo "error: Xcode build failed. Full log: $derived/build.log" >&2
        trap - EXIT
        exit 1
    }

src="$derived/Build/Products/Release-iphoneos/CitizenRadio.app/Metadata.appintents"
if [[ ! -f "$src/extract.actionsdata" ]]; then
    echo "error: Xcode did not produce $src/extract.actionsdata" >&2
    exit 1
fi

rm -rf "$dest"
mkdir -p "$dest"
cp "$src"/* "$dest"/
echo "Wrote $dest:"
ls -1 "$dest"
