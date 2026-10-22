# 0003: Boot package

Status: Implemented
Related: [0001](0001-platform-registration.md), [0002](0002-devices-and-kernels.md), [`docs/lifecycle-dispatch.md`](../../docs/lifecycle-dispatch.md), [`book/packages/omarchy-chromebook-boot/`](../packages/omarchy-chromebook-boot/), [`book/packages/omarchy-chromebook/`](../packages/omarchy-chromebook/)

## Problem

depthcharge, a Chromebook's firmware, boots a signed FIT image (kernel, initramfs, device trees, command line) from a ChromeOS kernel partition. Nothing in Omarchy writes one, so after the first kernel update the machine keeps booting the old kernel against new modules, or does not boot at all. And there is no boot menu: a kernel that does not boot is a machine that needs a recovery card.

LazyOS writes the partition by hand (`install-kpart.sh`, after a kernel update, if you remember). omarchybook ran it from a pacman hook. Both write the partition they booted from, in place, so a bad kernel replaces the only good one.

## Shape

`omarchy-chromebook-boot` owns the kernel partitions. Every time the board's initramfs is built (a kernel update, a module option, `mkinitcpio -P`), mkinitcpio's post hook builds the signed image and writes it to the kernel partition that is **not** running, makes it the one to boot next with a single try, and leaves the running one alone. Once the new system is up, a boot service marks it successful. If it never comes up, depthcharge skips it on the next power-on and boots the previous partition by itself. `update-verify` checks after every update that the partition booting next holds exactly the installed kernel, initramfs and command line.

`omarchy-chromebook` is the runtime half: the action-row keyboard map, the key names Omarchy's keybindings menu shows, the journal cap for eMMC.

## Rejected approaches

- **Writing the running partition in place** (LazyOS, omarchybook, postmarketOS' boot-deploy). One bad kernel and the machine needs a card. depthcharge's priority/tries/successful flags exist to do A/B updates; ChromeOS uses them for every update. In place remains the fallback for a disk with one kernel partition.
- **A pacman hook on the kernel package.** It misses every other initramfs rebuild: Omarchy's first-boot hardware setup runs `mkinitcpio -P` directly, which fires no pacman hook, and so does a user changing a module option. mkinitcpio's post hooks (`/usr/lib/initcpio/post/`) run after every image it builds, whoever asked. mkinitcpio's own pacman hook already triggers on kernel installs and on changes under `/usr/lib/initcpio/`, so the post hook covers updates too.
- **`depthchargectl write` and `bless`.** They pick the target partition and command line by their own rules and configuration. The boot package needs the target, the command line and the records to agree with `update-verify`, so it uses `depthchargectl build` (the step LazyOS proved on the Hayato) and `cgpt` directly.
- **A separate `/boot` partition** (pmbootstrap's and LazyOS' 512 MiB ext2). depthcharge reads only the kernel partitions; `/boot` on the btrfs root keeps kernels inside snapshots, as on every Omarchy install.
- **A udev rule and the `video` group for the backlight** (omarchybook). Omarchy's brightness keys go through `brightnessctl`, which works through logind from the session on every other laptop. If it does not on a Chromebook, that is a bug to find, not a permission to paper over. omarchybook's version also ran before the owner existed on an image's first boot, so it never applied.

## Requirements

### Board, command line, image

- **R3.1** The board is resolved as [R2.4](0002-devices-and-kernels.md) says. In a chroot, where the device tree is the build host's, only `/etc/omarchy-chromebook/device` (or an explicit `--device`) counts. On a booted machine a configured board that disagrees with the device tree is an error. *Check:* `test/device-test.sh`.
- **R3.2** The command line is the board's `kernel-cmdline.conf`, then Omarchy's `KERNEL_CMDLINE[default]` from `/etc/default/limine` and `/etc/limine-entry-tool.d/*.conf` in name order, then `root=` and `rootflags=subvol=` from the `/` entry of `/etc/fstab`. A drop-in not owned by root or writable by others fails the build. *Check:* `test/cmdline-test.sh`.
- **R3.3** The image carries the board's kernel (`/boot/vmlinuz-linux-book-<flavor>`), its initramfs, the device trees `deviceinfo_dtb` selects from that kernel's release and no others, the board's depthcharge board name and compression, and ChromiumOS' developer keys. An image `futility` does not verify is never written. *Check:* `test/write-test.sh`.

### Writing

- **R3.4** `write` refuses to run in a chroot or on a kernel depthcharge did not load (no `kern_guid=`). *Check:* `test/write-test.sh`.
- **R3.5** On a disk with two kernel partitions, `write` writes the one not running, gives it the highest priority, one try and successful=0, and leaves the running one successful. *Check:* `test/write-test.sh`.
- **R3.6** On a disk with one kernel partition, `write` keeps its previous contents in `/var/lib/omarchy-chromebook-boot/` and writes it in place, successful. *Check:* `test/write-test.sh`.
- **R3.7** Every write reads the partition back and records, per PARTUUID, the image's hash and size and the inputs it was built from. Writing again with unchanged inputs changes nothing. *Check:* `test/write-test.sh`.
- **R3.8** `omarchy-chromebook-bless.service` marks the running partition successful once the system is up. *Check:* `test/write-test.sh` (the command); on hardware, the unit.
- **R3.9** The mkinitcpio post hook writes only for the board's own kernel's default initramfs, only on a booted Chromebook, and does nothing (successfully) in a chroot. *Check:* `test/write-test.sh`.

### Lifecycle

- **R3.10** `update-verify` passes only when the partition depthcharge boots next (highest priority, still bootable) was recorded with the current inputs and its bytes match the record. *Check:* `test/write-test.sh`.
- **R3.11** `setup-boot` records the board, writes its modules drop-in, enables the bless service, and writes the partition when it is stale (rebuilding the initramfs first if the modules changed). With `image-first-boot` it asks for Omarchy's deferred rebuild instead of writing. *Check:* `test/write-test.sh`.
- **R3.12** The package's mkinitcpio drop-in removes `autodetect` and `btrfs-overlayfs` from Omarchy's hooks. *Check:* `test/install-test.sh`.
- **R3.13** `setup-system` enables keyd once and never again after an administrator turns it off. *Check:* `omarchy-chromebook/test/all`.

## Design

### The pieces

| Piece | Path | Runs |
| --- | --- | --- |
| `omarchy-chromebook-boot` | `/usr/bin`, modules in `/usr/lib/omarchy-chromebook-boot/lib/` | everything below |
| `setup-boot`, `update-verify` | `/usr/lib/omarchy/chromebook-boot/` | `omarchy-lifecycle-dispatch` |
| `omarchy-chromebook-kpart` | `/usr/lib/initcpio/post/` | mkinitcpio, after each image |
| `omarchy-chromebook-bless.service` | `/usr/lib/systemd/system/` | each boot, after `local-fs.target` |
| `50-omarchy-chromebook.conf` | `/etc/mkinitcpio.conf.d/` | mkinitcpio |
| `setup-system` | `/usr/lib/omarchy/chromebook/` | `omarchy-lifecycle-dispatch` |

### An update, step by step

1. `pacman` installs `linux-book-mediatek-mt81`; mkinitcpio's pacman hook copies the kernel to `/boot` and builds the initramfs.
2. The post hook runs `omarchy-chromebook-boot mkinitcpio-post`: it is a booted Chromebook and the board's kernel, so `write`.
3. `write` finds the booted partition from `kern_guid=`, builds and verifies the image, writes partition B (A is running), reads it back, records it, `cgpt prioritize -i 2`, `cgpt add -i 2 -T 1 -S 0`.
4. `omarchy update` ends with `update-verify`: B boots next and matches the installed kernel, initramfs and command line.
5. Reboot. depthcharge spends B's try and boots it. `omarchy-chromebook-bless.service` marks B successful. The next update writes A.
6. If B hangs: power off, power on. B has no tries left and is not successful, so depthcharge boots A. A's kernel has its early modules in its own initramfs, enough to reach a console and repair. Its other modules survive only until a boot of the new kernel runs `linux-modules-cleanup`, so a fallback after a boot that got that far comes up without them (see Tasks).

### Records

`/var/lib/omarchy-chromebook-boot/partitions/<partuuid>`:

```
kpart_sha256=…
kpart_size=31457280
device=google-asurada
release=7.2.7-mt81
kernel_sha256=…
initramfs_sha256=…
dtbs_sha256=…
cmdline=quiet loglevel=2 … root=UUID=… rootflags=subvol=/@ rw rootwait
```

## Acceptance

On a Hayato booted from a card built by [0004](0004-image-and-install.md), one change per boot:

1. `omarchy-chromebook-boot status` lists both kernel partitions, the running one current, and `update-verify` passes.
2. `sudo mkinitcpio -P` writes the other partition with one try; the reboot boots it, and `status` shows it successful after login.
3. Fallback: `sudo omarchy-chromebook-boot write` after making the initramfs unbootable on purpose (a `MODULES` drop-in that omits the root filesystem's driver, on a test card): the reboot fails, the next power-on boots the previous partition, and `status` shows the failed one with no tries left.
4. A kernel package update through `omarchy update` ends with `update-verify` passing and boots.
5. The keyboard: Search+top row gives F1-F10, Ctrl+Alt+top row a console, the lid switch still suspends, and the brightness keys work without a udev rule (if they do not, file the bug: see Rejected approaches).
6. `cgpt show` on the eMMC after an install ([0004](0004-image-and-install.md)) shows two kernel partitions holding the same image.

## Tasks

- [x] Board resolution, command line, kpart build and verify
- [x] A/B and in-place writes, records, verify, bless, post hook, setup-boot
- [x] Runtime package: keyd, key names, journal cap, setup-system
- [x] Off-device tests (fixture disk), each key behaviour mutation-checked
- [ ] Hardware acceptance
- [ ] Factory reset operations (`reset-prepare`, `reset-verify`, `reset-commit`, `reset-rollback`): until they ship, a factory reset stops before changing anything, naming this package. Without LUKS the root's UUID and subvolume names stay the same across the reset, so `reset-prepare` is a `write-disk`-like rebuild from the factory root and `reset-rollback` restores the recorded images.
- [ ] Keep the previous kernel's modules until the new kernel is blessed: on a Chromebook, run `linux-modules-cleanup` from `omarchy-chromebook-bless.service` instead of early in boot, so a fallback boot has its modules too.
- [ ] keyd exclusion ids for boards beyond the Hayato (they hash the device names; check `keyd monitor` on each new board)

## Verification

None yet.

## Changelog

- 2026-10-22: created and implemented.
