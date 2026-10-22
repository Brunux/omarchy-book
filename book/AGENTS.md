# Working on Omarchy Book

These rules add to the repository's root [`AGENTS.md`](../AGENTS.md), which still applies to everything here (style, shebangs, tests, commit hygiene). Read both.

## The one rule: stay mergeable

This repository is a fork of [omacom/omarchy](https://github.com/omacom/omarchy) that merges upstream's `quattro` regularly. Every line changed outside `book/` is a line that can conflict on the next merge, so:

- **Put port work in `book/`.** Devices, kernels, platform packages, image tooling, specs and docs for this port live here and nowhere else. The one exception is the CI workflow, `.github/workflows/book-packages.yml`, because GitHub reads workflows from nowhere else.
- **Change upstream files only through a seam upstream already has**, and only in the shape upstream would accept as a pull request: a platform name in the places `AGENTS.md` lists under Platforms, a dispatch registration, a package list, a pacman template directory. [`specs/0001-platform-registration.md`](specs/0001-platform-registration.md) lists every upstream file the fork changes and why. A change outside `book/` that is not on that list needs the spec updated first.
- **Never fork an upstream behaviour by editing it.** If Omarchy does the wrong thing on a Chromebook, fix it in a platform package behind a dispatch operation, a drop-in or a platform file. If no seam exists, write the upstream change as its own commit, small and general, and record it in spec 0001 as a candidate pull request.
- **Slimming follows the same rule.** Memory work uses the knobs Omarchy has (disabled shell plugins, systemd presets and drop-ins, package subtraction) before it touches a default ([`specs/0005-memory-budget.md`](specs/0005-memory-budget.md)).

## Spec first

Work here is spec-driven ([`specs/README.md`](specs/README.md)):

1. A feature starts as a spec in `specs/` with the problem, the decision and its rejected alternatives, numbered requirements and acceptance checks.
2. Code lands against an accepted spec, and the commit names the requirements it implements.
3. A spec is only **Verified** once its acceptance checks have passed on hardware, with the report kept in the spec.

Small fixes inside an existing spec's scope need no new spec; a change of decision updates the spec in the same commit as the code.

## Devices and kernels

- A board is a directory in `devices/<codename>/`, named exactly as in pmaports (`google-asurada`, not `hayato`). Its files are listed in [`specs/0002-devices-and-kernels.md`](specs/0002-devices-and-kernels.md); `tools/check-devices` validates them.
- A kernel flavor is a directory in `kernels/<flavor>/`, named as pmaports' `linux-postmarketos-<flavor>`; its package is `linux-book-<flavor>`.
- Import from pmaports with `tools/pmaports-import`, which records the source commit in `PROVENANCE.md`. Hand edits to an imported file are allowed only with the reason next to them in `PROVENANCE.md`.
- No package, script or test may name a board, a disk (`mmcblk0`) or a depthcharge board name. Code reads them from the device profile.

## Packages

`packages/<name>/` follows the omarchy-mac-pkgs contract: `install DESTDIR` stages the package and enables nothing, `test/all` runs its tests from a copy of the directory alone, and each has a `README.md` and a `version`. The Arch recipes that build them are in `packages/<name>/PKGBUILD`.

## Hardware is the test that counts

Off-device tests prove the logic. Anything that writes a kernel partition, changes the initramfs or touches the boot command line is only done once it has booted on a real Chromebook: record the run (board, what was tested, `omarchy-chromebook-boot status` output) in the spec's Verification section. One risky boot change per test boot, so a failure names its cause.
