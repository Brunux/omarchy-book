#!/bin/bash

# Which board a machine is, and what its profile is allowed to contain.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
require_unprivileged "device profiles"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

machine "$work/m"
[[ $(boot device) == "google-asurada" ]] || fail "a Hayato's device tree picks the asurada profile" "$(boot device 2>&1)"
printf '%s\0' google,spherion-rev3 google,spherion mediatek,mt8192 >"$M/proc/device-tree/compatible"
[[ $(boot device) == "google-asurada" ]] || fail "a Spherion's device tree picks the asurada profile too"
printf '%s\0' google,krane-sku176 google,krane mediatek,mt8183 >"$M/proc/device-tree/compatible"
[[ $(boot device) == "google-kukui" ]] || fail "a Krane picks its own profile, not the first one listed"
# A profile for one SKU beats the board's, even when it sorts after it.
profiles=$M/root/usr/share/omarchy-chromebook-boot/devices
cp -r "$profiles/google-kukui" "$profiles/google-zz-krane-sku176"
echo google,krane-sku176 >"$profiles/google-zz-krane-sku176/compatible"
[[ $(boot device) == "google-zz-krane-sku176" ]] || fail "the most specific token wins over profile order" "$(boot device 2>&1)"
pass "the most specific device-tree token any profile claims picks the board"

# The SoC alone names no board: two MT8192 Chromebooks need different profiles.
printf '%s\0' google,unknown-board mediatek,mt8192 >"$M/proc/device-tree/compatible"
if output=$(boot device 2>&1); then fail "an unknown board fails" "$output"; fi
[[ $output == *"no device profile matches this machine"* ]] || fail "an unknown board says why" "$output"
pass "a board no profile claims fails instead of guessing from the SoC"

machine "$work/m"
mkdir -p "$M/root/etc/omarchy-chromebook"
echo google-kukui >"$M/root/etc/omarchy-chromebook/device"
if output=$(boot device 2>&1); then fail "a configured board that is not this machine fails" "$output"; fi
[[ $output == *"device tree is the google-asurada board"*"says google-kukui"* ]] || fail "the mismatch names both boards" "$output"

# In a chroot the device tree is the build host's: only the configuration counts.
rm "$M/proc/1/root"
mkdir -p "$work/elsewhere"
ln -s "$work/elsewhere" "$M/proc/1/root"
[[ $(boot device) == "google-kukui" ]] || fail "a chroot uses the configured board, not the host's tree"
rm "$M/root/etc/omarchy-chromebook/device"
if output=$(boot device 2>&1); then fail "a chroot with no configured board fails" "$output"; fi
[[ $(boot device --device google-asurada) == "google-asurada" ]] || fail "an image build names its board"
pass "a configured board must agree with a booted machine, and is the only answer in a chroot"

# deviceinfo is data: a line that would run code if sourced is refused unrun.
machine "$work/m"
echo "deviceinfo_name=\"\$(touch $work/pwned)\"" >>"$M/root/usr/share/omarchy-chromebook-boot/devices/google-asurada/deviceinfo"
if output=$(boot cmdline 2>&1); then fail "a deviceinfo line with a command substitution is refused" "$output"; fi
[[ ! -e $work/pwned ]] || fail "deviceinfo is never sourced"
[[ $output == *"is not a deviceinfo_<key>"* ]] || fail "the refusal names the line" "$output"
machine "$work/m"
echo 'touch /tmp/x' >>"$M/root/usr/share/omarchy-chromebook-boot/devices/google-asurada/deviceinfo"
if boot cmdline >/dev/null 2>&1; then fail "a bare command in deviceinfo is refused"; fi
pass "deviceinfo is parsed as key=\"value\" lines and never run"
