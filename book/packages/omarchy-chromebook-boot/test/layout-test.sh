#!/bin/bash

# The Chromebook disk layout: its geometry and its fstab.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

layout() {
  bash -c '
    set -euo pipefail
    lib=$1; profiles=$2; shift 2
    for module in common device layout; do source "$lib/$module.sh"; done
    cb_init /
    cb_devices=$profiles
    cb_device=google-asurada
    cb_deviceinfo_read "$profiles/google-asurada/deviceinfo"
    "$@"
  ' layout "$PACKAGE_DIR/lib" "$work/profiles" "$@"
}

fixture_profiles "$work/profiles"
# A 32 GiB eMMC: 67108864 sectors.
geometry=$(layout cb_layout_geometry 67108864) || fail "the geometry of a 32 GiB disk" "$geometry"
expected="1 8192 262144 kernel KERN-A
2 270336 262144 kernel KERN-B
3 532480 66576351 data OMARCHY"
[[ $geometry == "$expected" ]] || fail "two kernel partitions at the board's offset and size, then the root up to the backup GPT" "$geometry"
pass "the layout puts two kernel partitions where the board's deviceinfo says, and the root after them, short of the backup GPT"

if output=$(layout cb_layout_geometry 4194304 2>&1); then fail "a 2 GiB disk is refused" "$output"; fi
[[ $output == *"too small"* ]] || fail "the refusal says why" "$output"
pass "a disk too small for Omarchy is refused before anything is written"

fstab=$(layout cb_layout_fstab 1234-abcd)
for line in "UUID=1234-abcd / btrfs noatime,compress=zstd,subvol=/@ 0 0" \
  "UUID=1234-abcd /home btrfs noatime,compress=zstd,subvol=/@home 0 0" \
  "UUID=1234-abcd /var/log btrfs noatime,compress=zstd,subvol=/@log 0 0" \
  "UUID=1234-abcd /var/cache/pacman/pkg btrfs noatime,compress=zstd,subvol=/@pkg 0 0"; do
  grep -qxF "$line" <<<"$fstab" || fail "fstab mounts the ISO's subvolume with the ISO's options: $line" "$fstab"
done
pass "the fstab mounts the ISO's four subvolumes with the ISO's options"
