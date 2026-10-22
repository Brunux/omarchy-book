# Omarchy Book

Omarchy on devices the ISO cannot boot, starting with ARM Chromebooks, and slimmed to start a desktop in under 1 GiB of RAM.

This directory is the only part of the fork that upstream [omacom/omarchy](https://github.com/omacom/omarchy) does not have. Everything else in the repository is upstream Omarchy plus the small, upstreamable registration of the `aarch64-chromebook` platform (see [specs/0001-platform-registration.md](specs/0001-platform-registration.md)). Keeping the port here, and only here, is what keeps `git merge upstream/quattro` cheap.

## What is here

| Path | What it is |
| --- | --- |
| [`specs/`](specs/) | The specs this port is built from, one per feature, with their status. Start at [`specs/README.md`](specs/README.md). |
| [`devices/`](devices/) | One directory per supported board: its postmarketOS `deviceinfo`, the device-tree `compatible` strings that identify it, its kernel, command line, early modules and packages. Adding a board is adding a directory ([specs/0002](specs/0002-devices-and-kernels.md)). |
| [`kernels/`](kernels/) | One directory per kernel flavor: an Arch `PKGBUILD`, the kernel config and the patch series, imported from pmaports. Several boards share a flavor. |
| [`packages/`](packages/) | The platform packages, in the shape of [omacom/omarchy-mac-pkgs](https://github.com/omacom/omarchy-mac-pkgs): `omarchy-chromebook-boot` (the depthcharge boot chain behind `omarchy-lifecycle-dispatch`), `omarchy-chromebook` (runtime setup and platform files), and the recipes for tools no configured repository carries. |
| [`tools/`](tools/) | Maintainer tools: importing a board from pmaports, building a card image, measuring a session's memory. |

## How it fits Omarchy

Omarchy already has the seams this needs, and the port uses them instead of patching around them:

- **Platform detection.** `omarchy-hw-platform` prints `aarch64-chromebook` on any ARM Chromebook (a `google,` board in the device tree), whatever its SoC.
- **Lifecycle dispatch.** Boot setup, update verification and factory reset run through `omarchy-lifecycle-dispatch`, which hands them to `omarchy-chromebook-boot` on a Chromebook, exactly as Apple Silicon hands them to `omarchy-mac-boot` ([`docs/lifecycle-dispatch.md`](../docs/lifecycle-dispatch.md)).
- **Image builds.** A card image is Omarchy installed in a chroot with the image manifest naming `aarch64-chromebook`, so hardware setup and the owner wizard run on the Chromebook's first boot, the way upstream's prebuilt images do.
- **Package lists and pacman templates.** `install/omarchy-aarch64-chromebook.packages` and `default/pacman/aarch64-chromebook/` are the platform's, in the places upstream reserves for them.

Nothing board-specific lives outside this directory.

## The boot chain in one paragraph

A Chromebook's firmware, depthcharge, has no UEFI and reads no filesystem. It loads a signed FIT image (kernel, initramfs, device trees and command line) from a ChromeOS kernel partition chosen by the GPT's priority, tries and successful flags. So installing a kernel into `/boot` changes nothing until that partition is rewritten. `omarchy-chromebook-boot` rewrites it after every initramfs build (an mkinitcpio post hook), into the kernel partition that is not running, and marks it to be tried once: a kernel that fails to boot falls back to the previous one by itself ([specs/0003](specs/0003-boot-package.md)).

## Status

See [`specs/README.md`](specs/README.md) for each feature's state. In short: the platform registration is done and tested; the device, kernel, boot package and image tooling are written and tested off-device, and wait for their first hardware run on the Google Hayato (MT8192, `google-asurada`); the memory work starts from a measurement on that machine.

## Provenance

The kernel, device knowledge and boot method come from [postmarketOS](https://postmarketos.org) (pmaports), by way of [LazyOS](https://github.com/Brunux/LazyOS), where they were proven on the Hayato. The first Omarchy port, [omarchybook](https://github.com/Brunux/omarchybook), proved the Arch Linux ARM side (the depthcharge-tools recipe, the vboot developer keys, the platform package split). Each imported file says where it came from in its directory's `PROVENANCE.md`.
