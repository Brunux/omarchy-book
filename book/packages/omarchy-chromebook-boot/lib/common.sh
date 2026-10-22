# shellcheck shell=bash
# Shared state for omarchy-chromebook-boot. Sourced, never run.
#
# Two roots are in play and never confused:
#
#   * the live system: /proc (the command line depthcharge passed, the device
#     tree the firmware handed over, PID 1's root) and the block devices. Only a
#     booted Chromebook has one worth reading.
#   * the target root: the system whose kernel partition is being built, / on
#     a booted machine, or an image being assembled in a chroot (--root).
#
# Root always reads the real /proc. An unprivileged test may point the live
# view at a fixture with OMARCHY_CHROMEBOOK_PROC, the way Omarchy's detector
# takes OMARCHY_PROC_ROOT, so no environment variable can make a root run read
# a fake command line.

cb_fail() {
  echo "Error: $*" >&2
  exit 1
}

cb_note() {
  echo "$*" >&2
}

# cb_init <target-root>
cb_init() {
  local root=${1:-/}

  [[ $root == /* ]] || cb_fail "the target root must be an absolute path: $root"
  cb_root=${root%/}

  if (( EUID != 0 )) && [[ -n ${OMARCHY_CHROMEBOOK_PROC:-} ]]; then
    cb_proc=${OMARCHY_CHROMEBOOK_PROC%/}
  else
    cb_proc=/proc
  fi

  cb_share=$cb_root/usr/share/omarchy-chromebook-boot
  cb_devices=$cb_share/devices
  cb_keys=$cb_share/devkeys
  cb_config=$cb_root/etc/omarchy-chromebook
  cb_state=$cb_root/var/lib/omarchy-chromebook-boot
}

# True when this process runs in a chroot of the live system: its / is not PID
# 1's. stat -L follows /proc/1/root to the directory it names; without it the
# comparison is against the symlink and never matches. Both sides must be read,
# so a /proc that hides PID 1 is not taken for a chroot.
cb_in_chroot() {
  local own pid1

  own=$(stat -Lc '%d:%i' / 2>/dev/null) || return 1
  pid1=$(stat -Lc '%d:%i' "$cb_proc/1/root" 2>/dev/null) || return 1
  [[ $own != "$pid1" ]]
}

# The PARTUUID depthcharge booted, from kern_guid= on the live command line,
# or nothing when this kernel was not loaded by depthcharge.
cb_kern_guid() {
  local word

  [[ -r $cb_proc/cmdline ]] || return 1
  for word in $(<"$cb_proc/cmdline"); do
    if [[ $word == kern_guid=* ]]; then
      printf '%s\n' "${word#kern_guid=}"
      return 0
    fi
  done
  return 1
}

# A booted Chromebook whose kernel partition this process may write: depthcharge
# loaded the running kernel, and this is not a chroot (whose /proc/cmdline would
# name the host's partition).
cb_booted_on_depthcharge() {
  cb_kern_guid >/dev/null && ! cb_in_chroot
}

cb_sha256() {
  sha256sum "$1" | cut -d' ' -f1
}
