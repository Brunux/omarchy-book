# shellcheck shell=bash
# The kernel command line a kernel partition carries. Sourced after common.sh
# and device.sh.
#
# depthcharge passes the FIT's command line as it is (prepending kern_guid= and
# cros_secure itself), so everything the kernel needs is assembled here, in this
# order, and the kernel keeps the last value of a repeated parameter:
#
#   1. the board's kernel-cmdline.conf (pmaports' fragments for the hardware);
#   2. Omarchy's own command line: KERNEL_CMDLINE[default] from
#      /etc/default/limine and /etc/limine-entry-tool.d/*.conf, the files
#      Omarchy and its hardware leaves already write on every platform (quiet
#      splash, the initramfs and console fixes, a leaf's quirk). Reading them
#      keeps a Chromebook's boot the same as everyone else's without a second
#      place to configure it;
#   3. the root filesystem, from the target's /etc/fstab.

# A root-run reader takes only files root owns and nobody else can write; a
# fixture run takes the caller's own.
cb_trusted_file() {
  local file=$1 owner mode

  [[ -f $file && ! -L $file ]] || return 1
  read -r owner mode < <(stat -c '%u %a' -- "$file") || return 1
  (( owner == EUID && (8#$mode & 8#022) == 0 ))
}

# KERNEL_CMDLINE[default] as limine-entry-tool builds it from its config files.
cb_cmdline_omarchy() {
  local -a files=()
  local file

  [[ -f $cb_root/etc/default/limine ]] && files+=("$cb_root/etc/default/limine")
  for file in "$cb_root"/etc/limine-entry-tool.d/*.conf; do
    [[ -f $file ]] && files+=("$file")
  done
  for file in "${files[@]}"; do
    cb_trusted_file "$file" || cb_fail "refusing $file: it must be a regular file owned by root and writable by no one else"
  done
  (( ${#files[@]} )) || return 0

  # The files are shell, written for limine-entry-tool, which sources them as
  # root too. A subshell keeps their other settings out of this process.
  (
    declare -A KERNEL_CMDLINE=()
    for file in "${files[@]}"; do
      # shellcheck disable=SC1090
      source "$file" >/dev/null 2>&1 || exit 1
    done
    printf '%s\n' "${KERNEL_CMDLINE[default]:-}"
  ) || cb_fail "could not read Omarchy's kernel command line from ${files[*]}"
}

# root= and rootflags= for the target's / entry in /etc/fstab.
cb_cmdline_root() {
  local fstab=$cb_root/etc/fstab source mountpoint options option flags=""

  [[ -f $fstab ]] || cb_fail "no $fstab to read the root filesystem from"
  while read -r source mountpoint _ options _; do
    [[ -n $source && $source != \#* ]] || continue
    [[ $mountpoint == "/" ]] || continue

    for option in ${options//,/ }; do
      [[ $option == subvol=* ]] && flags=$option
    done
    printf 'root=%s' "$source"
    [[ -z $flags ]] || printf ' rootflags=%s' "$flags"
    printf ' rw rootwait\n'
    return 0
  done <"$fstab"
  cb_fail "$fstab has no entry for /"
}

# The whole command line, on one line, single-spaced. Each part fails closed: a
# kernel partition built without Omarchy's settings or without its root would
# boot the wrong system or none.
cb_cmdline() {
  local -a parts=()
  local part

  while IFS= read -r part; do
    parts+=("$part")
  done < <(cb_profile_lines "$cb_profile/kernel-cmdline.conf")
  part=$(cb_cmdline_omarchy) || exit 1
  parts+=("$part")
  part=$(cb_cmdline_root) || exit 1
  parts+=("$part")

  printf '%s\n' "${parts[*]}" | tr -s '[:space:]' ' ' | sed -e 's/^ //' -e 's/ $//'
}
