#!/usr/bin/env bash
# Builds CitizenRadio with xtool, adds the App Intents metadata that Xcode would
# have generated, and installs the app on a connected iPhone.
#
# Without this metadata the Shortcuts app does not show the Play CitizenRadio and
# Stop CitizenRadio actions (https://github.com/xtool-org/xtool/issues/145).
#
# Usage: scripts/xtool-install.sh [extra options for `xtool install`, e.g. --udid <id>]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
metadata="$root/Configuration/AppIntents/Metadata.appintents"
app="$root/xtool/CitizenRadio.app"

if [[ -t 1 ]]; then
    bold=$'\033[1m' green=$'\033[32m' red=$'\033[31m' reset=$'\033[0m'
else
    bold='' green='' red='' reset=''
fi
step() { echo; echo "${bold}==> $*${reset}"; }
fail() { echo "${red}error:${reset} $*" >&2; exit 1; }

step "Checking requirements"
command -v xtool >/dev/null || fail "xtool is not installed. Follow https://xtool.sh/tutorials/xtool/first-app/ first."
command -v python3 >/dev/null || fail "python3 is required. Install it with your package manager (Arch: sudo pacman -S python, Debian/Ubuntu: sudo apt install python3)."
[[ -f "$metadata/extract.actionsdata" ]] || fail "Missing $metadata. Update your checkout of the repository."
[[ "$(xtool auth status 2>&1)" == *"Logged in"* ]] || fail "xtool is not logged in. Run: xtool auth login"
echo "xtool, python3, metadata and Apple account login are ready."

cd "$root"

# Signing first gives the app its final bundle ID. xtool prefixes it with your
# team ID (XTL-...), and Siri phrase metadata must name that exact ID.
step "Building and signing the app (this can take a few minutes)"
xtool dev build --sign

[[ -d "$app" ]] || fail "xtool did not produce $app."

step "Adding Play/Stop Shortcuts actions"
python3 - "$app" "$metadata" <<'PY'
import pathlib, plistlib, re, shutil, sys

app, metadata = map(pathlib.Path, sys.argv[1:])
bundle_id = plistlib.loads((app / "Info.plist").read_bytes())["CFBundleIdentifier"]

dest = app / "Metadata.appintents"
shutil.rmtree(dest, ignore_errors=True)
shutil.copytree(metadata, dest)

ssu = dest / "root.ssu.yaml"
if ssu.exists():
    text = re.sub(r"(?m)^(\s*bundleIdentifier:).*$", rf"\1 {bundle_id}", ssu.read_text())
    ssu.write_text(text)

print(f"Added Metadata.appintents for {bundle_id}")
PY

step "Installing on your iPhone (keep it connected and unlocked)"
xtool install "$@" "$app"

echo
echo "${green}${bold}Done!${reset} Open Shortcuts and search for \"CitizenRadio\" to find the"
echo "Play CitizenRadio and Stop CitizenRadio actions."
echo "If they do not appear right away, open CitizenRadio once, then check again."
