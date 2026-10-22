#!/bin/bash

# What `install` stages, and the mkinitcpio drop-in it ships.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fixture_profiles "$work/profiles"
"$PACKAGE_DIR/install" "$work/root" "$work/profiles" || fail "install stages the package"
root=$work/root
for entrypoint in setup-boot update-verify; do
  [[ -x $root/usr/lib/omarchy/chromebook-boot/$entrypoint ]] || fail "the $entrypoint entrypoint is where the dispatcher looks"
done
[[ $(readlink -f "$root/usr/bin/omarchy-chromebook-boot") == "$root/usr/lib/omarchy-chromebook-boot/bin/omarchy-chromebook-boot" ]] ||
  fail "the command on PATH is the one beside its modules"
[[ -x $root/usr/lib/initcpio/post/omarchy-chromebook-kpart ]] || fail "mkinitcpio's post hook is executable"
[[ -f $root/usr/share/omarchy-chromebook-boot/devices/google-asurada/deviceinfo ]] || fail "board profiles are shipped"
[[ ! -e $root/usr/share/omarchy-chromebook-boot/devices/google-asurada/packages ]] || fail "build-only profile files are not shipped"
pass "install stages the command, the entrypoints, the hook and the board profiles, and only their runtime files"

if "$PACKAGE_DIR/install" relative >/dev/null 2>&1; then fail "install refuses a relative destination"; fi
if "$PACKAGE_DIR/install" "$work/x" "$work/none" >/dev/null 2>&1; then fail "install refuses a missing profiles directory"; fi
pass "install refuses a relative destination or no profiles"

# Omarchy's busybox HOOKS line, then the drop-in.
hooks=$(
  HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
  source "$root/etc/mkinitcpio.conf.d/50-omarchy-chromebook.conf"
  echo "${HOOKS[*]}"
)
[[ $hooks == "base udev plymouth keyboard microcode modconf kms keymap consolefont block encrypt filesystems fsck" ]] ||
  fail "the drop-in removes autodetect and btrfs-overlayfs, and keeps the rest in order" "$hooks"
pass "the mkinitcpio drop-in drops autodetect and btrfs-overlayfs from Omarchy's hooks"
