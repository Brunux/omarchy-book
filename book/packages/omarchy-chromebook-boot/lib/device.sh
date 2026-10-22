# shellcheck shell=bash
# Device profiles: which board this is, and what its profile says. Sourced
# after common.sh.
#
# A profile is <devices>/<codename>/, copied from book/devices/ when the
# package is built:
#
#   deviceinfo           pmaports' description of the board, key="value" lines
#   compatible           the device-tree names that identify the board, one per line
#   kernel               the kernel flavor (package linux-book-<flavor>)
#   kernel-cmdline.conf  the board's kernel command line, one fragment per line
#   modules-initfs       modules the initramfs must carry, one per line
#
# deviceinfo is parsed, never sourced: installing a profile must not be a way to
# run code as root, and a line that is not key="value" is refused rather than
# guessed at.

# cb_deviceinfo_read <file>: fills the associative array cb_deviceinfo.
cb_deviceinfo_read() {
  local file=$1 line number=0 key value

  declare -gA cb_deviceinfo=()
  [[ -f $file ]] || cb_fail "no deviceinfo at $file"
  while IFS= read -r line || [[ -n $line ]]; do
    (( ++number ))
    [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ $line =~ ^(deviceinfo_[a-z0-9_]+)=\"([^\"\`\$\\]*)\"[[:space:]]*$ ]]; then
      key=${BASH_REMATCH[1]#deviceinfo_}
      value=${BASH_REMATCH[2]}
      cb_deviceinfo[$key]=$value
    else
      cb_fail "$file:$number is not a deviceinfo_<key>=\"<value>\" line: $line"
    fi
  done <"$file"
}

# Lines of a profile file, without comments and blank lines.
cb_profile_lines() {
  local file=$1

  [[ -f $file ]] || return 0
  sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e '/^$/d' "$file"
}

# The codename whose `compatible` claims the most specific token of the live
# device tree. The tree lists the board first and the SoC last
# ("google,hayato-rev1", "google,hayato", "mediatek,mt8192"), so the first token
# any profile claims wins.
cb_device_from_tree() {
  local tree token profile claimed
  local -a tokens

  for tree in "$cb_proc/device-tree/compatible" "${cb_proc%/proc}/sys/firmware/devicetree/base/compatible"; do
    [[ -r $tree ]] && break
  done
  [[ -r $tree ]] || return 1

  mapfile -d '' -t tokens <"$tree"
  for token in "${tokens[@]}"; do
    for profile in "$cb_devices"/*/; do
      [[ -f $profile/compatible ]] || continue
      while IFS= read -r claimed; do
        if [[ $claimed == "$token" ]]; then
          basename "$profile"
          return 0
        fi
      done < <(cb_profile_lines "$profile/compatible")
    done
  done
  return 1
}

# The configured board: what the image builder or a previous setup recorded.
cb_device_configured() {
  local codename

  [[ -f $cb_config/device ]] || return 1
  codename=$(cb_profile_lines "$cb_config/device" | head -n1)
  [[ -n $codename ]] || return 1
  printf '%s\n' "$codename"
}

# cb_device_resolve [codename]: sets cb_device and cb_profile, and reads the
# profile's deviceinfo. An explicit codename wins (the image builder names the
# board it builds for). A booted Chromebook answers from its own device tree,
# and a configured board that disagrees with it is a mistake worth stopping for.
# In a chroot the tree is the build host's, so only the configuration counts.
cb_device_resolve() {
  local requested=${1:-} live="" configured=""

  configured=$(cb_device_configured) || configured=""
  if ! cb_in_chroot; then
    live=$(cb_device_from_tree) || live=""
  fi

  if [[ -n $requested ]]; then
    cb_device=$requested
  elif [[ -n $live ]]; then
    if [[ -n $configured && $configured != "$live" ]]; then
      cb_fail "this machine's device tree is the $live board, but $cb_config/device says $configured"
    fi
    cb_device=$live
  elif [[ -n $configured ]]; then
    cb_device=$configured
  else
    cb_fail "no device profile matches this machine, and $cb_config/device names none (profiles: $cb_devices)"
  fi

  [[ $cb_device =~ ^[a-z0-9][a-z0-9-]*$ ]] || cb_fail "not a device codename: $cb_device"
  cb_profile=$cb_devices/$cb_device
  [[ -d $cb_profile ]] || cb_fail "no profile for the $cb_device board in $cb_devices"
  cb_deviceinfo_read "$cb_profile/deviceinfo"

  cb_flavor=$(cb_profile_lines "$cb_profile/kernel" | head -n1)
  [[ -n $cb_flavor ]] || cb_fail "the $cb_device profile names no kernel flavor"
  cb_pkgbase=linux-book-$cb_flavor
}

# What a Chromebook's boot chain needs from deviceinfo; fails naming the key.
cb_device_require_depthcharge() {
  local key

  [[ ${cb_deviceinfo[generate_depthcharge_image]:-} == "true" ]] ||
    cb_fail "the $cb_device board does not boot depthcharge (deviceinfo_generate_depthcharge_image)"
  for key in depthcharge_board dtb; do
    [[ -n ${cb_deviceinfo[$key]:-} ]] || cb_fail "the $cb_device profile has no deviceinfo_$key"
  done
}
