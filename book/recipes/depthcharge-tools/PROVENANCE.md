# Provenance: depthcharge-tools

`depthchargectl` builds the signed FIT image a Chromebook boots from its kernel partition. Arch Linux ARM does not carry it (its `vboot-utils` has only `cgpt`, `futility` and `vbutil_*`), so the recipe travels with this repository and is built into the Chromebook package repository ([specs/0006](../../specs/0006-package-repository.md)).

## Source

The AUR recipe, `https://aur.archlinux.org/depthcharge-tools.git` at `9f20e678ed63f4b9f20e82ace555577c0c88c7b5` (2024-01-05), by way of [omarchybook](https://github.com/Brunux/omarchybook) (`upstream/depthcharge-tools/`), where it was built in a clean Arch Linux ARM chroot and produced a kernel partition `futility` verifies. `pkgver` (0.6.2), the upstream source and its checksum are the AUR's.

## Changes from the AUR

1. `0001-argparse-nargs-zero.patch`: Python 3.14's argparse rejects the `nargs=0` positionals the 2021 release builds at import time, so even `depthchargectl --version` failed. Cherry-picked from upstream commit `1c123c8`.
2. `0002-drop-pkg_resources.patch`: the release imports `pkg_resources`, which setuptools no longer ships. Same upstream commit; brings in `python-packaging`.
3. `dtc`, `vboot-utils` and `uboot-tools` are runtime dependencies: `depthchargectl build` runs `fdtget`/`fdtput`, `futility` and `mkimage`, which the AUR recipe does not declare. `python-setuptools` is a build dependency.

Only compatibility fixes are taken from upstream's later history, not its behaviour changes: the kernel partitions LazyOS boots on the Hayato were built with 0.6.2's semantics. Moving to a newer release is a change to verify on hardware like a kernel change.
