# 0004: Image and install

Status: Implemented
Related: [0003](0003-boot-package.md), [`install/helpers/image-target.sh`](../../install/helpers/image-target.sh), [`docs/file-layout.md`](../../docs/file-layout.md) (image builds), [`book/tools/build-image`](../tools/build-image)

## Problem

Omarchy installs from its ISO, which boots UEFI. A Chromebook has no UEFI: depthcharge boots only a signed kernel partition on the internal disk or on a card in developer mode. So there must be another way in, and it must not become a second, drifting installer.

## Shape

A **card image**: Omarchy installed in a chroot exactly as the ISO installs it, into the Chromebook layout, with upstream's image mode turned on. Flash it, boot it from the card, and the first boot runs hardware setup on the real board and then Omarchy's own owner wizard (keyboard, account, password). The card is then a working Omarchy. `omarchy-chromebook-boot install-internal` copies it onto the eMMC.

### The layout

| # | Label | Type | Size | |
| --- | --- | --- | --- | --- |
| 1 | `KERN-A` | ChromeOS kernel | the board's (`deviceinfo_cgpt_kpart_size`, 128 MiB on the Hayato) | at `deviceinfo_cgpt_kpart_start` |
| 2 | `KERN-B` | ChromeOS kernel | the same | |
| 3 | `OMARCHY` | Linux data | the rest, less the backup GPT | btrfs labelled `OMARCHY`; `@`, `@home`, `@log`, `@pkg` mounted `noatime,compress=zstd`, as the ISO makes them |

## Rejected approaches

- **A live installer card** with its own wizard (LazyOS' v0.4 plan, the ISO's configurator). It would duplicate the configurator for one platform. Upstream's image mode plus its owner wizard already is "Omarchy, set up on first boot"; the Mac's installer and the VM images use it.
- **Building on the device from LazyOS** (Debian). No pacstrap, and a Debian host's packages would leak into the image. The builder runs on Arch Linux ARM: a GitHub arm64 runner, an ARM box or a Chromebook already running this port.
- **LUKS in v1.** The kernel partition carries the initramfs, so the staged unlock key would have to live inside a signed image until owner setup re-keys and rewrites it. Possible (the provisioning dispatch operations exist for exactly this), but a second risky boot change on top of the first. Chosen by the maintainer: unencrypted first, LUKS as its own spec.
- **ext4** (LazyOS). No snapshots, and Omarchy's update flow takes one before every update.
- **Copying the card's identity off in `install-internal`** (LazyOS emptied `machine-id`). Moving to internal storage is the same machine, and on Arch an empty `machine-id` on an installed system invites first-boot preset handling. The image, which is many machines, is sealed instead.

## Requirements

- **R4.1** `build-image --device <codename>` produces `omarchy-<codename>-<date>.img.xz` and its SHA-256, with the layout above. *Check:* `book/packages/omarchy-chromebook-boot/test/layout-test.sh` (geometry, fstab); a build on Arch Linux ARM.
- **R4.2** The image holds the packages the ISO would pacstrap for `aarch64-chromebook`: archinstall's base without x86 and Limine parts, `omarchy-dev` and `omarchy-settings-dev`, the board's kernel and packages, and `omarchy-pkg-defaults aarch64-chromebook` with Arch Linux ARM's names, adjusted by the lite profile unless `--profile full` ([R5.6](0005-memory-budget.md)). *Check:* the build log.
- **R4.3** The image is set up by `omarchy-apply-system --defer-provisioning --first-install` with the image manifest `platform=aarch64-chromebook` and the ISO's environment, so hardware setup and owner setup run on the first boot. *Check:* first boot on a Hayato.
- **R4.4** Both kernel partitions hold the image built from the system, the first at the higher priority, both successful; the system's records name both. *Check:* `test/write-test.sh` (write-disk); `omarchy-chromebook-boot status` on first boot.
- **R4.5** The image is sealed: empty `/etc/machine-id` (not `uninitialized`), no D-Bus machine id, no SSH host keys, empty package cache and journal, and `/etc/pacman.conf` is the published template even when built from a local repository. *Check:* inspecting a built image.
- **R4.6** `install-internal --disk <disk>` refuses the disk it runs from and any disk holding the running root, refuses mounted partitions, asks the person to type the disk's name unless `--yes`, then lays out the disk, copies each subvolume with its mountpoints kept empty, recreates snapper's `/.snapshots` subvolume, writes the fstab for the new filesystem and both kernel partitions. *Check:* on hardware (acceptance 4).

## Design

### Building

```
sudo book/tools/build-image --device google-asurada --output out/ [--size 8G] [--profile lite|full] [--repo ./repo]
```

1. Read the board's profile from `book/devices/` with the boot package's parser.
2. Write the platform's edge pacman template with its mirrorlist inlined (and `--repo` as a trusted local server when given); import `book/keys/*.gpg` into the host keyring.
3. Loop-attach the image, create the layout ([`lib/layout.sh`](../packages/omarchy-chromebook-boot/lib/layout.sh)), make the btrfs and its subvolumes, mount them.
4. Write `/etc/omarchy-chromebook/device` and the image manifest, then `pacstrap`. The post hook does nothing in the chroot.
5. Install the published pacman template and the fstab; run `omarchy-apply-system --defer-provisioning --first-install` in the chroot with the ISO's environment.
6. `initramfs-config`, `mkinitcpio -p linux-book-<flavor>`, `write-disk` on the loop device, enable the bless service.
7. Seal, unmount, compress.

### First boot

depthcharge boots `KERN-A` from the card (developer mode, `crossystem dev_boot_usb=1 dev_boot_signed_only=0`, then "external disk" in the firmware menu). `omarchy-provision-hardware` retires the manifest and runs the queued hardware leaves; the last runs `setup-boot image-first-boot` (records the board, asks for the rebuild) and `setup-system` (keyd). The rebuild runs `mkinitcpio -P`, whose post hook writes `KERN-B` with one try. Owner setup follows on tty1. The next reboot tries `KERN-B`.

### Moving to the eMMC

```
sudo omarchy-chromebook-boot install-internal --disk /dev/mmcblk0
```

The eMMC gets the layout, a copy of `@`, `@home` and `@log` (the package cache is left empty), the fstab for its new filesystem, and both kernel partitions. Remove the card and the Chromebook boots from the eMMC.

## Acceptance

On a Hayato:

1. Flash the image to a card, boot it: the owner wizard appears, the desktop starts, `omarchy-hw-platform` says `aarch64-chromebook`.
2. `omarchy-chromebook-boot status`: both partitions present; after the first-boot rebuild, B holds the board's current image with one try; after a reboot and login, B is successful.
3. Wi-Fi, Bluetooth, audio (speakers, headphones), display brightness, suspend on lid close and on the Lock key, and the touchpad work.
4. `install-internal` to the eMMC, remove the card, boot: same checks.
5. `omarchy update` on the eMMC install ends with `update-verify` passing.

## Tasks

- [x] Layout library, shared by the builder and `install-internal`, with tests
- [x] `build-image`
- [x] `install-internal`
- [ ] First build on Arch Linux ARM (needs the packages of [0006](0006-package-repository.md))
- [ ] Hardware acceptance
- [ ] LUKS (its own spec): the staged key in the kernel partition's initramfs, `provision-commit`/`provision-verify` rewriting both partitions without it

## Verification

None yet.

## Changelog

- 2026-10-22: created and implemented.
