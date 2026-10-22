#!/bin/bash

# Writing, verifying and blessing kernel partitions.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
require_unprivileged "kernel partition writes"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A partition still blank (zeros), or holding something other than a kpart.
written() { head -c 6 "$M/disk/p$1" | grep -qa kernel; }

holds() {
  local number=$1 image=$2
  cmp -s <(head -c "$(stat -c %s "$image")" "$M/disk/p$number") "$image"
}

# ── A/B ──────────────────────────────────────────────────────────────────────

machine "$work/m"
output=$(boot write 2>&1) || fail "write succeeds on a booted Chromebook" "$output"
staged=$M/root/var/lib/omarchy-chromebook-boot/staging/kpart
holds 2 "$staged" || fail "the partition that is not running gets the new image"
! written 1 || fail "the running partition is left as it was"
(( $(attr 2 P) > $(attr 1 P) )) || fail "the new partition boots first" "P1=$(attr 1 P) P2=$(attr 2 P)"
[[ $(attr 2 T) == 1 && $(attr 2 S) == 0 ]] || fail "the new partition gets one try and is not yet successful" "T=$(attr 2 T) S=$(attr 2 S)"
[[ $(attr 1 S) == 1 ]] || fail "the running partition stays successful, to fall back to"
grep -q -- "--board mt8192" "$M/depthchargectl.args" && grep -q -- "--compress lzma" "$M/depthchargectl.args" ||
  fail "the board and compression come from deviceinfo" "$(cat "$M/depthchargectl.args")"
grep -q -- "--vboot-keyblock $M/root/usr/share/omarchy-chromebook-boot/devkeys/kernel.keyblock" "$M/depthchargectl.args" ||
  fail "the package's developer keys sign the image" "$(cat "$M/depthchargectl.args")"
grep -q "mt8192-asurada-hayato-r1.dtb" "$staged" && grep -q "mt8192-asurada-spherion-r0.dtb" "$staged" &&
  ! grep -q krane "$staged" || fail "the image carries the board's device trees and no others" "$(cat "$staged")"
pass "an update writes the partition that is not running and gives it one try"

boot verify >/dev/null || fail "verify accepts the partition just written" "$(boot verify 2>&1)"
: >"$M/cgpt.log"
[[ $(boot write) == *"up to date"* ]] || fail "a second write with the same inputs does nothing"
! grep -q 'cgpt add\|cgpt prioritize' "$M/cgpt.log" || fail "an up-to-date partition's flags are not touched" "$(cat "$M/cgpt.log")"
pass "verify accepts it, and writing again changes nothing"

# The new kernel booted: bless marks it, and the next update goes to the other side.
echo "kern_guid=$UUID_B" >"$M/proc/cmdline"
boot bless >/dev/null || fail "bless succeeds"
[[ $(attr 2 S) == 1 ]] || fail "bless marks the running partition successful"
echo "initramfs two" >"$M/root/boot/initramfs-$PKGBASE.img"
if output=$(boot verify 2>&1); then fail "verify catches an initramfs built after the write" "$output"; fi
[[ $output == *"partition 2, which boots next"* ]] || fail "verify names the stale partition" "$output"
boot write >/dev/null || fail "the next update writes"
holds 1 "$staged" || fail "the next update goes to the other partition"
(( $(attr 1 P) > $(attr 2 P) )) && [[ $(attr 1 T) == 1 && $(attr 1 S) == 0 ]] || fail "and gives it the try"
pass "after a good boot, bless keeps it and the next update alternates"

# The try failed: depthcharge skips the partition, and the previous one boots.
echo 0 >"$M/disk/attrs/1.T"
boot verify >/dev/null 2>&1 && fail "verify fails when the fallback partition is older than the system"
grep -q "partition 2" <(boot verify 2>&1) || fail "after a failed try, the partition booting next is the previous one"
pass "a partition whose try is spent is not what boots next"

# A partition whose bytes are not what was recorded fails verification.
machine "$work/m"
boot write >/dev/null
printf 'garbage' | dd of="$M/disk/p2" conv=notrunc status=none
if output=$(boot verify 2>&1); then fail "verify catches a partition that does not hold its recorded image" "$output"; fi
[[ $output == *"does not hold the image recorded"* ]] || fail "verify says so" "$output"
pass "verify reads the partition, not only the record"

# ── one kernel partition ─────────────────────────────────────────────────────

machine "$work/m" 1
echo "what was there" | dd of="$M/disk/p1" conv=notrunc status=none
output=$(boot write 2>&1) || fail "write succeeds on a disk with one kernel partition" "$output"
holds 1 "$staged" || fail "the only partition is written in place"
backup=$M/root/var/lib/omarchy-chromebook-boot/previous-$UUID_A.kpart
[[ $(head -c 14 "$backup") == "what was there" ]] || fail "its previous contents are kept"
[[ $(attr 1 S) == 1 ]] || fail "it stays successful, since there is nothing to fall back to"
boot verify >/dev/null || fail "verify accepts it"
pass "a disk with one kernel partition is written in place, keeping what it held"

# ── where nothing may be written ─────────────────────────────────────────────

machine "$work/m"
rm "$M/proc/1/root"
mkdir -p "$work/host"
ln -s "$work/host" "$M/proc/1/root"
if output=$(boot write 2>&1); then fail "a chroot refuses to write" "$output"; fi
[[ $output == *"chroot"* ]] || fail "the refusal says why" "$output"
boot mkinitcpio-post /boot/vmlinuz-$PKGBASE /boot/initramfs-$PKGBASE.img >/dev/null 2>&1 ||
  fail "the post hook does nothing, successfully, in a chroot"
[[ ! -e $M/cgpt.log ]] || fail "nothing touched a partition in a chroot" "$(cat "$M/cgpt.log")"
pass "a chroot, whose /proc/cmdline is the host's, never writes a partition"

machine "$work/m"
sed -i 's/kern_guid=[^ ]*//' "$M/proc/cmdline"
if boot write >/dev/null 2>&1; then fail "a kernel not loaded by depthcharge refuses to write"; fi
machine "$work/m"
boot mkinitcpio-post /boot/vmlinuz-linux-other /boot/initramfs-linux-other.img >/dev/null || fail "the post hook ignores another kernel"
boot mkinitcpio-post /boot/vmlinuz-$PKGBASE /boot/initramfs-$PKGBASE-fallback.img >/dev/null || fail "the post hook ignores a fallback image"
[[ ! -e $M/cgpt.log ]] || fail "neither touched a partition"
boot mkinitcpio-post /boot/vmlinuz-$PKGBASE /boot/initramfs-$PKGBASE.img >/dev/null || fail "the post hook writes for the board's kernel"
holds 2 "$staged" || fail "the board's kernel's initramfs reaches the partition"
pass "the post hook writes only for the board's own kernel and initramfs, and only from a booted Chromebook"

machine "$work/m"
if FUTILITY_FAIL=1 boot write >/dev/null 2>&1; then fail "an image futility can't verify is never written"; fi
! written 2 || fail "the partition is untouched after a failed verification"
pass "an image futility rejects is never written"

# ── a new disk ───────────────────────────────────────────────────────────────

machine "$work/m"
rm "$M/proc/1/root"
ln -s "$work/host" "$M/proc/1/root"
output=$(boot write-disk --disk "$M/disk/device" --device google-asurada 2>&1) || fail "write-disk works from a chroot" "$output"
holds 1 "$staged" && holds 2 "$staged" || fail "every kernel partition of the new disk gets the image"
[[ $(attr 1 P) == 3 && $(attr 2 P) == 2 ]] || fail "the first partition boots first" "P1=$(attr 1 P) P2=$(attr 2 P)"
[[ $(attr 1 S) == 1 && $(attr 2 S) == 1 ]] || fail "both start successful, so a slow first boot costs nothing"
[[ -f $M/root/var/lib/omarchy-chromebook-boot/partitions/$UUID_A && -f $M/root/var/lib/omarchy-chromebook-boot/partitions/$UUID_B ]] ||
  fail "both partitions are recorded in the new system"
! written 3 || fail "a data partition is never written"
pass "write-disk writes every kernel partition of a new disk and records them in its system"

# ── setup-boot ───────────────────────────────────────────────────────────────

machine "$work/m"
boot setup image-first-boot >/dev/null || fail "setup-boot runs on an image's first boot"
[[ $(cat "$M/root/etc/omarchy-chromebook/device") == "google-asurada" ]] || fail "setup records the board"
grep -qx 'MODULES+=(anx7625 panel-edp cros-ec-keyb)' "$M/root/etc/mkinitcpio.conf.d/60-omarchy-chromebook-device.conf" ||
  fail "setup writes the board's early modules" "$(cat "$M/root/etc/mkinitcpio.conf.d/60-omarchy-chromebook-device.conf")"
[[ -f $M/root/var/lib/omarchy/image/boot-rebuild ]] || fail "an image's first boot asks for the deferred rebuild"
grep -q 'systemctl enable --quiet omarchy-chromebook-bless.service' "$M/calls.log" || fail "setup enables the blessing"
[[ ! -e $M/cgpt.log ]] || fail "an image's first boot writes no partition itself"
pass "setup-boot on an image's first boot records the board and asks for the rebuild that writes the partition"

: >"$M/calls.log"
boot setup >/dev/null || fail "setup-boot runs again"
! grep -q mkinitcpio "$M/calls.log" || fail "an unchanged modules drop-in rebuilds nothing"
holds 2 "$M/root/var/lib/omarchy-chromebook-boot/staging/kpart" || fail "setup-boot writes the partition when it is stale"
echo 'evdev' >>"$M/root/usr/share/omarchy-chromebook-boot/devices/google-asurada/modules-initfs"
boot setup >/dev/null || fail "setup-boot runs after a profile change"
grep -q "mkinitcpio -p $PKGBASE" "$M/calls.log" || fail "a changed modules drop-in rebuilds the initramfs"
pass "setup-boot is idempotent and rebuilds the initramfs only when the board's modules changed"
