# shellcheck shell=bash
# ChromeOS kernel partitions: which exist, which one is running, which boots
# next, and their priority/tries/successful flags. Sourced after common.sh.
#
# depthcharge boots the kernel partition with the highest priority among those
# still bootable (successful, or with tries left), decrementing tries before
# each attempt on one that is not yet successful. A disk with two kernel
# partitions can therefore update safely: write the one not running, make it
# the highest priority with one try, and mark it successful once it has booted
# (omarchy-chromebook-bless.service). A kernel that fails to boot spends its
# try, and the firmware falls back to the previous partition by itself.

# The GPT type of a ChromeOS kernel partition.
cb_kernel_type=fe3a2a5d-4f32-41a7-b725-accc3285a309

# Lines of "<path> <number> <partuuid>" for each kernel partition on <disk>.
cb_gpt_kernel_parts() {
  local disk=$1 path number type uuid

  while read -r path number type uuid; do
    [[ ${type,,} == "$cb_kernel_type" && -n $number ]] || continue
    printf '%s %s %s\n' "$path" "$number" "${uuid,,}"
  done < <(lsblk -nrpo NAME,PARTN,PARTTYPE,PARTUUID "$disk")
}

# cb_gpt_attr <disk> <number> <P|T|S>: priority, tries or successful.
cb_gpt_attr() {
  cgpt show -i "$2" "-$3" "$1"
}

# Sets cb_disk, cb_booted_path, cb_booted_number and cb_booted_uuid from the
# kern_guid depthcharge put on the running kernel's command line.
cb_gpt_booted() {
  local guid path number uuid

  guid=$(cb_kern_guid) || cb_fail "no kern_guid= on the kernel command line: depthcharge did not load this kernel"
  guid=${guid,,}
  cb_booted_path=$(findfs "PARTUUID=$guid" 2>/dev/null) || cb_fail "no partition has the PARTUUID $guid that depthcharge booted"
  cb_disk=/dev/$(lsblk -nro PKNAME "$cb_booted_path" | head -n1)
  [[ $cb_disk != "/dev/" ]] || cb_fail "cannot find the disk holding $cb_booted_path"

  cb_booted_number=""
  while read -r path number uuid; do
    if [[ $uuid == "$guid" ]]; then
      cb_booted_number=$number
      cb_booted_uuid=$uuid
    fi
  done < <(cb_gpt_kernel_parts "$cb_disk")
  [[ -n $cb_booted_number ]] || cb_fail "$cb_booted_path is not a ChromeOS kernel partition"
}

# cb_gpt_next_boot <disk>: "<path> <number> <partuuid>" of the partition the
# firmware boots next, or nothing when none is bootable.
cb_gpt_next_boot() {
  local disk=$1 path number uuid priority tries successful best="" best_priority=0

  while read -r path number uuid; do
    priority=$(cb_gpt_attr "$disk" "$number" P) || continue
    tries=$(cb_gpt_attr "$disk" "$number" T) || continue
    successful=$(cb_gpt_attr "$disk" "$number" S) || continue
    (( priority > 0 )) || continue
    (( successful == 1 || tries > 0 )) || continue
    if (( priority > best_priority )); then
      best="$path $number $uuid"
      best_priority=$priority
    fi
  done < <(cb_gpt_kernel_parts "$disk")
  [[ -n $best ]] || return 1
  printf '%s\n' "$best"
}

# Sets cb_target_path, cb_target_number, cb_target_uuid and cb_target_mode
# (ab or in-place) for an update of the booted disk: the lowest-priority kernel
# partition other than the running one, or the running one itself on a disk
# that has no other.
cb_gpt_target() {
  local path number uuid priority lowest=""

  cb_target_number=""
  while read -r path number uuid; do
    [[ $number != "$cb_booted_number" ]] || continue
    priority=$(cb_gpt_attr "$cb_disk" "$number" P) || continue
    if [[ -z $lowest ]] || (( priority < lowest )); then
      lowest=$priority
      cb_target_path=$path
      cb_target_number=$number
      cb_target_uuid=$uuid
    fi
  done < <(cb_gpt_kernel_parts "$cb_disk")

  if [[ -n $cb_target_number ]]; then
    cb_target_mode=ab
  else
    cb_target_path=$cb_booted_path
    cb_target_number=$cb_booted_number
    cb_target_uuid=$cb_booted_uuid
    cb_target_mode=in-place
  fi
}

# The bytes a partition holds of a kpart <size> bytes long, hashed.
cb_partition_sha256() {
  head -c "$2" "$1" | sha256sum | cut -d' ' -f1
}
