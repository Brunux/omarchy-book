# shellcheck shell=bash
# Shared fixtures for omarchy-chromebook-boot's tests. Sourced by each
# *-test.sh; needs nothing outside this package's directory.
#
# A fixture machine is a directory:
#
#   root/   the target root, staged by the package's own `install` with fixture
#           board profiles, plus a kernel, initramfs, device trees and fstab
#   proc/   the live view: cmdline (kern_guid=), device-tree/compatible, and
#           1/root, a link to / (booted) or elsewhere (a chroot)
#   disk/   the GPT: `table` (path number type partuuid per line), one file per
#           partition, and attrs/<number>.{P,T,S}
#   bin/    stand-ins for the tools that touch real hardware
#
# The command reads the fixture live view only when not root, as on a real
# machine root always reads /proc, so these tests skip as root.

set -euo pipefail

PACKAGE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
KERNEL_TYPE=fe3a2a5d-4f32-41a7-b725-accc3285a309
PKGBASE=linux-book-mediatek-mt81
RELEASE=7.2.7-mt81
UUID_A=0c6e5d33-1111-4a3b-9f00-00000000000a
UUID_B=0c6e5d33-2222-4a3b-9f00-00000000000b

pass() { echo "ok - $*"; }
skip() { echo "ok - $* # SKIP"; }
fail() {
  echo "not ok - $1"
  [[ -z ${2:-} ]] || printf '%s\n' "$2" | sed 's/^/# /'
  exit 1
}

require_unprivileged() {
  if (( EUID == 0 )); then
    skip "$1: root always reads the real /proc, so fixtures only work unprivileged"
    exit 0
  fi
}

# fixture_profiles <dir>: two boards, so matching has something to choose
# between.
fixture_profiles() {
  local dir=$1

  mkdir -p "$dir/google-asurada" "$dir/google-kukui"
  cat >"$dir/google-asurada/deviceinfo" <<'EOF'
# Reference: <https://postmarketos.org/deviceinfo>
deviceinfo_format_version="0"
deviceinfo_name="Google Asurada Chromebook"
deviceinfo_codename="google-asurada"
deviceinfo_dtb="mediatek/mt8192-asurada*"
deviceinfo_arch="aarch64"
deviceinfo_cgpt_kpart="/boot/vmlinuz.kpart"
deviceinfo_cgpt_kpart_start="8192"
deviceinfo_cgpt_kpart_size="262144"
deviceinfo_depthcharge_board="mt8192"
deviceinfo_depthcharge_compression="lzma"
deviceinfo_generate_depthcharge_image="true"
EOF
  printf 'google,hayato\ngoogle,spherion\n' >"$dir/google-asurada/compatible"
  echo mediatek-mt81 >"$dir/google-asurada/kernel"
  printf 'quiet\nloglevel=2\ntransparent_hugepage=madvise\n' >"$dir/google-asurada/kernel-cmdline.conf"
  printf 'anx7625\npanel-edp\ncros-ec-keyb\n' >"$dir/google-asurada/modules-initfs"
  echo "not shipped" >"$dir/google-asurada/packages"

  sed -e 's/asurada/kukui/g' -e 's/mt8192/mt8183/g' "$dir/google-asurada/deviceinfo" >"$dir/google-kukui/deviceinfo"
  # Kukui boards are MT8183, and the SoC token alone must never pick a board.
  printf 'google,krane\n' >"$dir/google-kukui/compatible"
  echo mediatek-mt81 >"$dir/google-kukui/kernel"
}

# machine <dir> [partitions]: a booted Hayato with 1 or 2 (default) kernel
# partitions, running partition A, its kernel installed and its initramfs built.
machine() {
  local dir=$1 partitions=${2:-2} number uuid

  rm -rf "$dir"
  mkdir -p "$dir/proc/device-tree" "$dir/proc/1" "$dir/disk/attrs" "$dir/bin" "$dir/profiles"
  # The stand-ins in bin/ find the machine through it.
  export M=$dir

  fixture_profiles "$dir/profiles"
  "$PACKAGE_DIR/install" "$dir/root" "$dir/profiles" >/dev/null

  local root=$dir/root modules=$dir/root/usr/lib/modules/$RELEASE
  mkdir -p "$root/boot" "$modules/dtbs/mediatek" "$root/etc/limine-entry-tool.d"
  echo "kernel $RELEASE" >"$modules/vmlinuz"
  echo "$PKGBASE" >"$modules/pkgbase"
  cp "$modules/vmlinuz" "$root/boot/vmlinuz-$PKGBASE"
  echo "initramfs one" >"$root/boot/initramfs-$PKGBASE.img"
  echo "hayato dtb" >"$modules/dtbs/mediatek/mt8192-asurada-hayato-r1.dtb"
  echo "spherion dtb" >"$modules/dtbs/mediatek/mt8192-asurada-spherion-r0.dtb"
  echo "krane dtb" >"$modules/dtbs/mediatek/mt8183-kukui-krane-sku176.dtb"
  cat >"$root/etc/fstab" <<'EOF'
# <file system> <dir> <type> <options> <dump> <pass>
UUID=5d6e-root /home btrfs rw,noatime,compress=zstd,subvol=/@home 0 0
UUID=5d6e-root / btrfs rw,noatime,compress=zstd,subvol=/@ 0 0
EOF
  printf 'KERNEL_CMDLINE[default]+=" quiet splash initramfs_async=0"\n' >"$root/etc/limine-entry-tool.d/omarchy-defaults.conf"

  printf '%s\0' google,hayato-rev1 google,hayato mediatek,mt8192 >"$dir/proc/device-tree/compatible"
  echo "console=tty0 kern_guid=$UUID_A root=UUID=5d6e-root" >"$dir/proc/cmdline"
  ln -s / "$dir/proc/1/root"

  # The whole disk, as write-disk is given it.
  : >"$dir/disk/device"
  : >"$dir/disk/table"
  for number in $(seq 1 "$partitions"); do
    if (( number == 1 )); then uuid=$UUID_A; else uuid=$UUID_B; fi
    truncate -s 1M "$dir/disk/p$number"
    echo "$dir/disk/p$number $number $KERNEL_TYPE $uuid" >>"$dir/disk/table"
    echo $(( partitions - number + 1 )) >"$dir/disk/attrs/$number.P"
    echo 0 >"$dir/disk/attrs/$number.T"
    echo 1 >"$dir/disk/attrs/$number.S"
  done
  # A data partition the command must leave alone.
  truncate -s 1M "$dir/disk/p3"
  echo "$dir/disk/p3 3 0fc63daf-8483-4772-8e79-3d69d8477de4 0c6e5d33-3333-4a3b-9f00-00000000000c" >>"$dir/disk/table"

  stubs "$dir/bin"
}

stubs() {
  local bin=$1

  cat >"$bin/lsblk" <<'EOF'
#!/bin/bash
# -nrpo NAME,PARTN,PARTTYPE,PARTUUID <disk> lists the table; -nro PKNAME <part>
# names the disk.
case "$*" in
  *PKNAME*) echo fixture-disk ;;
  *) cat "$M/disk/table" ;;
esac
EOF
  cat >"$bin/findfs" <<'EOF'
#!/bin/bash
uuid=${1#PARTUUID=}
awk -v uuid="$uuid" '$4 == uuid { print $1; found = 1 } END { exit !found }' "$M/disk/table"
EOF
  cat >"$bin/blockdev" <<'EOF'
#!/bin/bash
[[ $1 == --getsize64 ]] && stat -c %s "$2"
EOF
  cat >"$bin/cgpt" <<'EOF'
#!/bin/bash
# show -i N -P|-T|-S DISK, add -i N [-P p] [-T t] [-S s] DISK, prioritize -i N DISK.
echo "cgpt $*" >>"$M/cgpt.log"
command=$1; shift
while (( $# > 1 )); do
  case $1 in
    -i) n=$2; shift 2 ;;
    -P | -T | -S)
      if [[ $command == show ]]; then field=${1#-}; shift; else eval "set_${1#-}=$2"; shift 2; fi
      ;;
    *) shift ;;
  esac
done
attrs=$M/disk/attrs
case $command in
  show) cat "$attrs/$n.$field" ;;
  add)
    [[ -z ${set_P:-} ]] || echo "$set_P" >"$attrs/$n.P"
    [[ -z ${set_T:-} ]] || echo "$set_T" >"$attrs/$n.T"
    [[ -z ${set_S:-} ]] || echo "$set_S" >"$attrs/$n.S"
    ;;
  prioritize)
    top=0
    for file in "$attrs"/*.P; do (( $(<"$file") > top )) && top=$(<"$file"); done
    (( $(<"$attrs/$n.P") == top )) && [[ $(grep -lx "$top" "$attrs"/*.P | wc -l) == 1 ]] || echo $(( top < 15 ? top + 1 : 15 )) >"$attrs/$n.P"
    ;;
esac
EOF
  cat >"$bin/depthchargectl" <<'EOF'
#!/bin/bash
# Records its arguments and writes an "image" that changes with every input.
printf '%q ' "$@" >"$M/depthchargectl.args"
while (( $# )); do
  case $1 in
    --kernel) kernel=$2; shift 2 ;;
    --initramfs) initramfs=$2; shift 2 ;;
    --kernel-cmdline) cmdline=$2; shift 2 ;;
    --fdtdir) fdtdir=$2; shift 2 ;;
    --output) output=$2; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z ${DEPTHCHARGECTL_FAIL:-} ]] || exit 1
{ cat "$kernel" "$initramfs"; echo "$cmdline"; ls "$fdtdir"; } >"$output"
EOF
  cat >"$bin/futility" <<'EOF'
#!/bin/bash
[[ -z ${FUTILITY_FAIL:-} ]] || { echo "Body verification failed"; exit 0; }
echo "Kernel partition: $2"
echo "Body verification succeeded."
EOF
  for tool in systemctl mkinitcpio; do
    printf '#!/bin/bash\necho "%s $*" >>"$M/calls.log"\n' "$tool" >"$bin/$tool"
  done
  chmod +x "$bin"/*
}

# Runs the installed command on the fixture machine, with its root as the
# target root (on a Chromebook that is /).
boot() {
  OMARCHY_CHROMEBOOK_PROC="$M/proc" PATH="$M/bin:$PATH" "$M/root/usr/bin/omarchy-chromebook-boot" "$@" --root "$M/root"
}

attr() { cat "$M/disk/attrs/$1.$2"; }
