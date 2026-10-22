# shellcheck shell=bash
# The kernel partition image (kpart): what goes in, how it is built, and the
# record of what each kernel partition holds. Sourced after common.sh,
# device.sh and cmdline.sh.
#
# A kpart is a FIT image (kernel, initramfs, the board's device trees and the
# command line) inside a vboot preamble signed with ChromiumOS' developer keys,
# which a Chromebook in developer mode boots (dev_boot_signed_only=0). It is
# built with depthchargectl, exactly as postmarketOS' boot-deploy and LazyOS
# build it on the Hayato, and checked with futility before anything writes it.

# cb_inputs_resolve: sets cb_kernel, cb_initramfs, cb_release and the array
# cb_dtbs for the board's kernel in the target root.
cb_inputs_resolve() {
  local dir candidate glob
  local -a matches=() releases=()

  cb_device_require_depthcharge
  cb_kernel=$cb_root/boot/vmlinuz-$cb_pkgbase
  cb_initramfs=$cb_root/boot/initramfs-$cb_pkgbase.img
  [[ -f $cb_kernel ]] || cb_fail "no kernel at $cb_kernel (is $cb_pkgbase installed?)"
  [[ -f $cb_initramfs ]] || cb_fail "no initramfs at $cb_initramfs (run mkinitcpio -p $cb_pkgbase)"

  # The release whose modules directory belongs to this kernel package and
  # holds the image mkinitcpio copied to /boot. During an upgrade the old
  # release can still be there (kernel-modules-hook keeps the running one), so
  # the image decides between them.
  for dir in "$cb_root"/usr/lib/modules/*/; do
    [[ -f $dir/pkgbase && $(<"$dir/pkgbase") == "$cb_pkgbase" ]] || continue
    releases+=("$dir")
    if [[ -f $dir/vmlinuz ]] && cmp -s "$dir/vmlinuz" "$cb_kernel"; then
      candidate=$dir
    fi
  done
  if [[ -z ${candidate:-} ]]; then
    (( ${#releases[@]} == 1 )) || cb_fail "cannot tell which of ${#releases[@]} $cb_pkgbase releases $cb_kernel is"
    candidate=${releases[0]}
  fi
  candidate=${candidate%/}
  cb_release=${candidate##*/}

  # deviceinfo_dtb is a glob relative to the dtbs directory, without .dtb
  # ("mediatek/mt8192-asurada*"), and may name several.
  cb_dtbs=()
  for glob in ${cb_deviceinfo[dtb]}; do
    # The glob is meant to expand here.
    # shellcheck disable=SC2206
    matches=("$candidate"/dtbs/$glob.dtb)
    [[ -e ${matches[0]} ]] || cb_fail "no device tree matches $glob.dtb in $candidate/dtbs"
    cb_dtbs+=("${matches[@]}")
  done
}

# The inputs, one key=value per line: what a kernel partition is built from.
# Two partitions built from the same inputs boot the same system.
cb_inputs() {
  local dtb cmdline

  cmdline=$(cb_cmdline) || exit 1
  printf 'device=%s\n' "$cb_device"
  printf 'release=%s\n' "$cb_release"
  printf 'kernel_sha256=%s\n' "$(cb_sha256 "$cb_kernel")"
  printf 'initramfs_sha256=%s\n' "$(cb_sha256 "$cb_initramfs")"
  printf 'dtbs_sha256=%s\n' "$(for dtb in "${cb_dtbs[@]}"; do printf '%s %s\n' "${dtb##*/}" "$(cb_sha256 "$dtb")"; done | sha256sum | cut -d' ' -f1)"
  printf 'cmdline=%s\n' "$cmdline"
}

# cb_kpart_build <output>
cb_kpart_build() {
  local output=$1 work cmdline key

  cmdline=$(cb_cmdline) || exit 1
  for key in kernel.keyblock kernel_subkey.vbpubk kernel_data_key.vbprivk; do
    [[ -f $cb_keys/$key ]] || cb_fail "the vboot developer key $cb_keys/$key is missing"
  done

  work=$(mktemp -d) || cb_fail "cannot create a work directory"
  mkdir "$work/dtbs" "$work/tmp"
  cp "${cb_dtbs[@]}" "$work/dtbs/"

  cb_note "Building the kernel partition for the $cb_device board ($cb_release)"
  cb_note "  command line: $cmdline"
  if ! depthchargectl build --root none \
    --board "${cb_deviceinfo[depthcharge_board]}" \
    --kernel "$cb_kernel" \
    --kernel-cmdline "$cmdline" \
    --initramfs "$cb_initramfs" \
    --fdtdir "$work/dtbs" \
    --compress "${cb_deviceinfo[depthcharge_compression]:-lzma}" \
    --vboot-keyblock "$cb_keys/kernel.keyblock" \
    --vboot-public-key "$cb_keys/kernel_subkey.vbpubk" \
    --vboot-private-key "$cb_keys/kernel_data_key.vbprivk" \
    --timestamp "${SOURCE_DATE_EPOCH:-$(date +%s)}" \
    --tmpdir "$work/tmp" \
    --output "$output" >&2; then
    rm -rf "$work"
    cb_fail "depthchargectl could not build the kernel partition"
  fi
  rm -rf "$work"
  cb_kpart_verify "$output"
}

# A kpart futility accepts: a vboot kernel preamble whose body verifies.
cb_kpart_verify() {
  local image=$1 output

  output=$(futility show "$image" 2>&1) || cb_fail "futility rejected $image: $output"
  [[ $output == *"Body verification succeeded"* ]] || cb_fail "futility could not verify the body of $image"
}

# ── records ──────────────────────────────────────────────────────────────────
#
# Each write leaves a record per partition (by PARTUUID): the kpart's hash and
# size, and the inputs it was built from. update-verify compares the record of
# the partition that boots next with the inputs as they are now, and the
# partition's bytes with the hash, so a missed rebuild and a failed write both
# show.

cb_record_path() {
  printf '%s/partitions/%s\n' "$cb_state" "${1,,}"
}

# cb_record_write <partuuid> <kpart> <inputs-file>
cb_record_write() {
  local record

  record=$(cb_record_path "$1")
  mkdir -p "${record%/*}"
  {
    printf 'kpart_sha256=%s\n' "$(cb_sha256 "$2")"
    printf 'kpart_size=%s\n' "$(stat -c %s "$2")"
    cat "$3"
  } >"$record.tmp"
  mv -f "$record.tmp" "$record"
}

# cb_record_get <partuuid> <key>
cb_record_get() {
  local record

  record=$(cb_record_path "$1")
  [[ -f $record ]] || return 1
  sed -n "s/^$2=//p" "$record" | head -n1
}

# The recorded inputs of a partition, in cb_inputs' format.
cb_record_inputs() {
  local record

  record=$(cb_record_path "$1")
  [[ -f $record ]] || return 1
  grep -v -e '^kpart_sha256=' -e '^kpart_size=' "$record"
}
