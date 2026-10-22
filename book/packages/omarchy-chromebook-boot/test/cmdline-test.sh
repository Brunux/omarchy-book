#!/bin/bash

# The command line a kernel partition carries.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
require_unprivileged "the kernel command line"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

machine "$work/m"
# Drop-ins are read in name order, as limine-entry-tool's glob reads them: a
# leaf's 50-leaf.conf before omarchy-defaults.conf.
printf 'KERNEL_CMDLINE[default]+=" fred=on"\n' >"$M/root/etc/limine-entry-tool.d/50-leaf.conf"
expected="quiet loglevel=2 transparent_hugepage=madvise fred=on quiet splash initramfs_async=0 root=UUID=5d6e-root rootflags=subvol=/@ rw rootwait"
actual=$(boot cmdline) || fail "the command line builds" "$actual"
[[ $actual == "$expected" ]] || fail "board, then Omarchy's drop-ins in order, then the root from fstab" "expected: $expected
actual:   $actual"
pass "the command line is the board's, then Omarchy's, then the root's"

mkdir -p "$M/root/etc/default"
printf 'KERNEL_CMDLINE[default]+=" resume=UUID=x"\n' >"$M/root/etc/default/limine"
[[ $(boot cmdline) == *"transparent_hugepage=madvise resume=UUID=x fred=on quiet splash"* ]] ||
  fail "/etc/default/limine comes before the drop-ins" "$(boot cmdline)"
pass "/etc/default/limine is read before the drop-ins, as limine-entry-tool does"

# A drop-in someone else could have written never reaches a root-run build.
chmod g+w "$M/root/etc/limine-entry-tool.d/50-leaf.conf"
if output=$(boot cmdline 2>&1); then fail "a group-writable drop-in is refused" "$output"; fi
[[ $output == *"refusing"*"50-leaf.conf"* ]] || fail "the refusal names the file" "$output"
pass "an untrusted drop-in fails the build instead of being skipped"

machine "$work/m"
sed -i '/ \/ /d' "$M/root/etc/fstab"
if output=$(boot cmdline 2>&1); then fail "an fstab with no root fails" "$output"; fi
[[ $output == *"has no entry for /"* ]] || fail "the missing root is named" "$output"
printf 'PARTUUID=abc / ext4 defaults 0 1\n' >>"$M/root/etc/fstab"
[[ $(boot cmdline) == *" root=PARTUUID=abc rw rootwait" ]] || fail "a root without a subvolume gets no rootflags" "$(boot cmdline)"
pass "the root comes from fstab, with rootflags only for a subvolume, and its absence fails"
