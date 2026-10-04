#!/usr/bin/env bash
# Runs the checks that must pass before a commit. ADR 0005 owns this procedure.
# Usage: scripts/check.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

fail() {
    echo "error: $*" >&2
    exit 1
}

echo "==> Core tests (Linux)"
# Without --build-system native, swift test cannot find the GCC 16 C++ headers for BoringSSL in swift-crypto. See ADR 0007.
swift test --build-system native

echo "==> iOS build in Swift 6 language mode (xtool)"
command -v xtool >/dev/null || fail "xtool is not on PATH. Install xtool, then run this script again."
xtool dev build || fail "ADR 0005 §Decision: the iOS build must pass in Swift 6 language mode. Correct the compiler errors above."

echo "==> App Intents in the binary"
command -v llvm-nm >/dev/null || fail "llvm-nm is not on PATH. Install LLVM, then run this script again."
binary="xtool/CitizenRadio.app/CitizenRadio"
symbols="$(llvm-nm "$binary")"
for intent in PlayB6IntentV StopB6IntentV; do
    grep -q "$intent" <<<"$symbols" || fail "ADR 0003 §Invariants: $binary has no $intent symbols. \
The linker removed RadioIntents.o. Make sure that CitizenRadioApp.init() calls RadioShortcuts.updateAppShortcutParameters()."
done

echo "==> All checks passed"
