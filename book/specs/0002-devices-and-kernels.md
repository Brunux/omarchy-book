# 0002: Devices and kernels

Status: Implemented
Related: [0003](0003-boot-package.md), [`book/devices/`](../devices/), [`book/kernels/`](../kernels/), [`book/tools/`](../tools/)

## Problem

Every board needs four things Omarchy cannot know: the kernel that drives it, where its firmware wants the kernel partition, which device trees to boot, and the command-line and early-module quirks its hardware needs. postmarketOS has already worked this out for hundreds of boards, in pmaports, and keeps it current. LazyOS and omarchybook each copied the Hayato's answers by hand, which worked for one board and does not scale: a second board meant a second round of copying, and nothing said when the copy had drifted from pmaports.

## Shape

A board is data, not code: a directory in `book/devices/` holding pmaports' own files, plus the little this port adds. A kernel is a directory in `book/kernels/` holding pmaports' recipe repackaged for Arch. Several boards share a kernel. Tools import both from pmaports, report drift, and validate everything with the same parser the device runs. Adding a supported board is adding a directory and passing `book/tools/check-devices`; no script, package or test changes.

## Rejected approaches

- **Board knowledge in scripts** (LazyOS' `lib.sh` sourcing one `deviceinfo`, a `DEVICE=` variable): fine for one board, but it made the build host and the device read different copies, and nothing checked them.
- **Our own device format.** pmaports' `deviceinfo` already names everything the boot chain needs, is documented, and is what a re-import compares against. Inventing fields would turn every import into a translation.
- **Sourcing `deviceinfo`.** It is shell syntax, but the boot package reads it as root; a profile must not be able to run code. It is parsed as `deviceinfo_<key>="<value>"` lines and anything else is refused.
- **Matching boards by SoC.** `mediatek,mt8192` names a dozen different Chromebooks with different panels and audio. Profiles claim board names only, and `check-devices` refuses a SoC.
- **One kernel package per board.** pmaports builds one kernel per SoC family for a reason: the patches and config are the family's. Boards point at a flavor.

## Requirements

- **R2.1** A board directory holds `deviceinfo` (pmaports'), `compatible` (its device-tree board names), `kernel` (a flavor), and optionally `kernel-cmdline.conf`, `modules-initfs`, `packages`, plus `PROVENANCE.md` and `APKBUILD.reference`. *Check:* `book/tools/check-devices`.
- **R2.2** `deviceinfo` is parsed, never sourced, and a line that is not `deviceinfo_<key>="<value>"` fails the parse. *Check:* `book/packages/omarchy-chromebook-boot/test/device-test.sh`.
- **R2.3** No two boards claim the same compatible string, and none claims a SoC. *Check:* `check-devices`.
- **R2.4** On a machine, the board is the profile claiming the most specific token of `/proc/device-tree/compatible`, whatever the order profiles sort in. *Check:* `device-test.sh`.
- **R2.5** A kernel flavor is `book/kernels/<flavor>/` with a `PKGBUILD` whose `pkgbase` is `linux-book-<flavor>`, `config.aarch64`, `patches/series` naming every patch in order, and `PROVENANCE.md` listing each config change from pmaports with its reason. *Check:* `check-devices`.
- **R2.6** The kernel package installs Arch's layout (`/usr/lib/modules/<release>/{vmlinuz,pkgbase,dtbs/}`), so mkinitcpio's own pacman hooks produce `/boot/vmlinuz-<pkgbase>` and `/boot/initramfs-<pkgbase>.img`. *Check:* on the build host, `pacman -Qlp linux-book-*.pkg.tar.zst`.
- **R2.7** `book/tools/pmaports-import` creates a new board or kernel from a pmaports commit, records that commit, and never overwrites an existing one: it prints the drift instead. A new board stays refused by `check-devices` until a person fills in its compatible strings and package names. *Check:* run against `google-asurada` (no drift but the documented `transparent_hugepage=madvise`), and against a new board in a scratch copy.

## Design

### A board

```
book/devices/google-asurada/
  deviceinfo            pmaports', byte for byte
  APKBUILD.reference    pmaports' device package, for the next re-import
  compatible            google,hayato / google,spherion
  kernel                mediatek-mt81
  kernel-cmdline.conf   pmaports' + transparent_hugepage=madvise
  modules-initfs        pmaports'
  packages              linux-firmware-mediatek, linux-firmware-realtek
  PROVENANCE.md         the pmaports commit, and every change from it
```

The boot package ships `deviceinfo`, `compatible`, `kernel`, `kernel-cmdline.conf` and `modules-initfs` for every board; `packages` is read only by the image builder.

### A kernel

`book/kernels/mediatek-mt81/` is pmaports' `linux-postmarketos-mediatek-mt81` 7.2.7: its patches in its order, its tarball checksum, its clang/lld build. The config is pmaports' with the changes LazyOS measured on the Hayato (MGLRU, schedutil, HZ=1000, dynamic preemption) and the netfilter and crypto options Omarchy's firewall and Bluetooth need. The kernel release is `7.2.7-mt81`, without pkgrel, so a rebuild keeps its modules directory.

### Adding a board

1. `book/tools/pmaports-import device <codename>` (and `kernel <flavor>` if its kernel is new).
2. Fill in `compatible` from the device trees' root nodes and `packages` with Arch Linux ARM's firmware names.
3. `book/tools/check-devices`.
4. Build an image for it ([0004](0004-image-and-install.md)) and boot it: a board is supported once [0003](0003-boot-package.md)'s acceptance has passed on it.

Two things to expect from boards beyond the Hayato: some depend on postmarketOS packages Arch does not have (Kukui's audio routing is `alsa-ucm-conf-cros`, not upstream `alsa-ucm-conf`), which then need a recipe in `book/recipes/`; and pmaports' `postmarketos-cros-common` carries ChromeOS defaults (its keyd configuration among them) that `omarchy-chromebook` replaces, so a board-specific one is worth a look at import time.

## Acceptance

1. The `linux-book-mediatek-mt81` package builds on Arch Linux ARM, and its `olddefconfig` diff against `config.aarch64` is empty apart from compiler-version symbols.
2. A Hayato boots it ([0003](0003-boot-package.md)), and `omarchy-chromebook-boot device` prints `google-asurada`.

## Tasks

- [x] google-asurada and mediatek-mt81, imported and compared with pmaports `63713ff7`
- [x] Board resolution in the boot package, with tests
- [x] `check-devices`, `pmaports-import`
- [ ] Kernel package built on Arch Linux ARM ([0006](0006-package-repository.md))
- [ ] Hardware acceptance

## Verification

None yet.

## Changelog

- 2026-10-22: created and implemented.
