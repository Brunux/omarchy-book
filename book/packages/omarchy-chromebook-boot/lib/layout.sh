# shellcheck shell=bash
# The disk layout of a Chromebook running Omarchy, and creating it. Sourced
# after common.sh and device.sh (it reads the board's deviceinfo).
#
#   p1  KERN-A   ChromeOS kernel  the board's kernel partition size (128 MiB
#   p2  KERN-B   ChromeOS kernel  on most), A/B for updates (lib/gpt.sh)
#   p3  OMARCHY  Linux data       btrfs, Omarchy's subvolumes, the rest
#
# The kernel partitions start where the board's deviceinfo says
# (cgpt_kpart_start) and take its size (cgpt_kpart_size), the geometry
# postmarketOS boots. There is no separate /boot: depthcharge reads only the
# kernel partitions, so the kernel and initramfs live in the root subvolume,
# inside its snapshots, as on every other Omarchy install.
#
# Creating it follows what LazyOS learned on this hardware:
#   * cgpt writes no protective MBR, and Linux refuses a GPT without one, so
#     parted writes the table and cgpt adds the ChromeOS entries to it;
#   * `cgpt create -z` zeroes the headers after writing them, so the next
#     `cgpt add` fails; it is never used, and both GPT areas are zeroed by
#     hand first so no stale header confuses `cgpt create`;
#   * the root ends 33 sectors before the end, leaving the backup GPT whole;
#   * partitions are found by number and checked by label afterwards, never by
#     their position in lsblk's output, which reorders after a re-read.

cb_layout_labels=(KERN-A KERN-B OMARCHY)

# cb_layout_geometry <total-sectors>: "<number> <start> <size> <type> <label>"
# per partition, in 512-byte sectors.
cb_layout_geometry() {
  local total=$1 start size root_start root_size

  start=${cb_deviceinfo[cgpt_kpart_start]:-8192}
  size=${cb_deviceinfo[cgpt_kpart_size]:-262144}
  [[ $start =~ ^[0-9]+$ && $size =~ ^[0-9]+$ ]] || cb_fail "the $cb_device profile's kernel partition geometry is not numeric"
  root_start=$(( start + 2 * size ))
  root_size=$(( total - root_start - 33 ))
  # 4 GiB is the least Omarchy installs into.
  (( root_size >= 8388608 )) || cb_fail "the disk is too small: $(( total / 2048 )) MiB, and Omarchy needs at least 4 GiB after the kernel partitions"

  printf '1 %s %s kernel %s\n' "$start" "$size" "${cb_layout_labels[0]}"
  printf '2 %s %s kernel %s\n' "$(( start + size ))" "$size" "${cb_layout_labels[1]}"
  printf '3 %s %s data %s\n' "$root_start" "$root_size" "${cb_layout_labels[2]}"
}

# cb_layout_create <disk>: replaces <disk>'s partition table with the layout.
cb_layout_create() {
  local disk=$1 total number start size type label

  total=$(blockdev --getsz "$disk")
  dd if=/dev/zero of="$disk" bs=512 count=34 conv=fsync status=none
  dd if=/dev/zero of="$disk" bs=512 seek=$(( total - 33 )) count=33 conv=fsync status=none
  parted -s "$disk" mktable gpt
  cgpt create "$disk"
  while read -r number start size type label; do
    cgpt add -i "$number" -b "$start" -s "$size" -t "$type" -l "$label" "$disk"
  done < <(cb_layout_geometry "$total")
  # The kernel partitions boot as good from the start; write-disk sets their
  # priorities once they hold a kernel.
  cgpt add -i 1 -S 1 -T 0 -P 0 "$disk"
  cgpt add -i 2 -S 1 -T 0 -P 0 "$disk"

  partprobe "$disk" 2>/dev/null || true
  partx -u "$disk" 2>/dev/null || true
  udevadm settle 2>/dev/null || sleep 2
}

# cb_layout_partition <disk> <number>: the partition's device, checked by label.
cb_layout_partition() {
  local disk=$1 number=$2 path label

  path=$(lsblk -nrpo NAME,PARTN "$disk" | awk -v n="$number" '$2 == n { print $1; exit }')
  [[ -n $path && $path != "$disk" ]] || cb_fail "no partition $number on $disk"
  label=$(lsblk -nro PARTLABEL "$path")
  [[ $label == "${cb_layout_labels[number - 1]}" ]] ||
    cb_fail "$path is labelled '$label', not ${cb_layout_labels[number - 1]}: refusing to use it"
  printf '%s\n' "$path"
}

# Omarchy's btrfs subvolumes and where each is mounted, as the ISO creates them.
cb_layout_subvolumes=("@:/" "@home:/home" "@log:/var/log" "@pkg:/var/cache/pacman/pkg")
cb_layout_mount_options=noatime,compress=zstd

# cb_layout_format_mount <root-partition> <mountpoint>: a fresh btrfs labelled
# OMARCHY with the subvolumes, mounted at <mountpoint>. Sets cb_root_uuid.
cb_layout_format_mount() {
  local partition=$1 mountpoint=$2 entry subvolume target

  mkfs.btrfs -f -q -L OMARCHY "$partition" >/dev/null
  cb_root_uuid=$(blkid -s UUID -o value "$partition")
  [[ -n $cb_root_uuid ]] || cb_fail "cannot read the UUID of the new filesystem on $partition"

  mkdir -p "$mountpoint"
  mount "$partition" "$mountpoint"
  for entry in "${cb_layout_subvolumes[@]}"; do
    btrfs subvolume create "$mountpoint/${entry%%:*}" >/dev/null
  done
  umount "$mountpoint"

  for entry in "${cb_layout_subvolumes[@]}"; do
    subvolume=${entry%%:*}
    target=$mountpoint${entry#*:}
    mkdir -p "$target"
    mount -o "$cb_layout_mount_options,subvol=$subvolume" "$partition" "$target"
  done
}

# cb_layout_umount <mountpoint>: the subvolumes, deepest first.
cb_layout_umount() {
  local mountpoint=$1 index

  for (( index = ${#cb_layout_subvolumes[@]} - 1; index >= 0; index-- )); do
    umount "$mountpoint${cb_layout_subvolumes[index]#*:}" 2>/dev/null || true
  done
}

# cb_layout_fstab <uuid>: the fstab for the layout.
cb_layout_fstab() {
  local uuid=$1 entry subvolume target

  echo "# Omarchy on a Chromebook (omarchy-chromebook-boot): one btrfs, its subvolumes."
  for entry in "${cb_layout_subvolumes[@]}"; do
    subvolume=${entry%%:*}
    target=${entry#*:}
    printf 'UUID=%s %s btrfs %s,subvol=/%s 0 0\n' "$uuid" "$target" "$cb_layout_mount_options" "$subvolume"
  done
}
