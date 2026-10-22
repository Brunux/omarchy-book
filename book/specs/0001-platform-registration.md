# 0001: Platform registration

Status: Implemented
Related: [`AGENTS.md`](../../AGENTS.md) (Platforms), [`docs/lifecycle-dispatch.md`](../../docs/lifecycle-dispatch.md), [0003](0003-boot-package.md), [0007](0007-upstream-sync.md)

## Problem

Unmodified, Omarchy reads a Chromebook's device tree (`google,hayato-rev1`, `google,hayato`, `mediatek,mt8192`) as plain `aarch64`. Every lifecycle operation is then a no-op, so nothing writes the kernel partition after an update, and a Snapdragon Chromebook (`google,lazor`, `qcom,sc7180`) is worse: it reads as `aarch64-qualcomm`, whose hardware leaves build Limine UKIs for a machine that boots depthcharge.

omarchybook solved this with a 382-line patch applied to a pinned upstream checkout at build time. That patch was the right content in the wrong place: it lived outside the tree it changed, so every upstream change could silently break it, and reading the port meant reading a diff of a diff.

## Shape

A Chromebook is a platform of its own, `aarch64-chromebook`, registered in the places upstream reserves for platforms and nowhere else. The registration is written as the pull request upstream would take: board-agnostic, tested in upstream's own test files, documented in upstream's docs. Everything a particular board needs lives in `book/`.

## Rejected approaches

- **`aarch64-google`** (omarchybook's name). The family is defined by the boot chain, not the vendor: Google's Pixel phones are `google,` boards too, and "Chromebook" is the word owners use. Packages read as `omarchy-chromebook`, like `omarchy-mac`.
- **`aarch64-mediatek`, or one family per SoC.** The SoC decides the kernel flavor, which is a property of the board's profile, not of the platform. Every ARM Chromebook shares the boot chain, which is what Omarchy has to handle differently.
- **Detecting depthcharge itself** (`/proc/device-tree/firmware/chromeos`, `kern_guid=` on the command line). Both exist only on a booted Chromebook, but image builds and chroots must name the platform without one; the image manifest covers those and the `google,` board covers the rest, the same way Apple and Snapdragon are detected.
- **Keeping the change as a patch.** See Problem.

## Requirements

- **R1.1** `omarchy-hw-platform` prints `aarch64-chromebook` for a device tree whose root `compatible` has a `google,` token, whatever the SoC token beside it, including `qcom,`. *Check:* `test/shell.d/hw-platform-test.sh` (Hayato, Krane, Lazor).
- **R1.2** A tree naming both `apple,` and `google,`, a `google,` tree on an x86 CPU, and a `google,` tree beside an NVIDIA N1x or GB10 signature are contradictions that fail closed. *Check:* same test.
- **R1.3** `omarchy-hw-aarch64-chromebook` answers for the family, refuses an ordinary Bash launch, and rejects every other family. *Check:* same test.
- **R1.4** An image manifest naming `platform=aarch64-chromebook` is accepted by the detector and by `install/helpers/image-target.sh`. *Check:* `test/shell.d/image-target-platform-test.sh`.
- **R1.5** `omarchy-lifecycle-dispatch` runs boot operations from `/usr/lib/omarchy/chromebook-boot` (package `omarchy-chromebook-boot`) and setup and app hooks from `/usr/lib/omarchy/chromebook` (package `omarchy-chromebook`). `setup-boot`, `update-verify` and the four reset operations are required; provisioning, `luks-slots` and `update-takeover` are optional. A Mac entrypoint never runs on a Chromebook. *Check:* `test/shell.d/lifecycle-dispatch-test.sh`.
- **R1.6** `omarchy-pkg-defaults aarch64-chromebook` composes base, aarch64 and `install/omarchy-aarch64-chromebook.packages`, in that order, and no other platform gets the Chromebook list. *Check:* `test/shell.d/platform-packages-test.sh`.
- **R1.7** The platform has its own pacman templates, edge only and default edge, with the Chromebook repository searched before Omarchy's so its build of the runtime wins. *Check:* `test/shell.d/pacman-templates-test.sh`.
- **R1.8** The upstream files the fork changes are exactly those listed below, plus the port's workflow. *Check:* `git diff --stat upstream/quattro -- . ':!book' ':!.github/workflows/book-packages.yml'` during a sync ([0007](0007-upstream-sync.md)).

## Design

### Why these operations are required

| Operation | Required | Reason |
| --- | --- | --- |
| `setup-boot` | yes | Hardware setup has no other way to write the kernel partition. |
| `update-verify` | yes | Nothing else checks that the next boot carries the installed kernel and initramfs. |
| `reset-prepare`, `reset-verify`, `reset-commit`, `reset-rollback` | yes | The generic reset rebuilds Limine UKIs. A boot package that lacks them stops the reset before anything changes, naming itself, instead of failing halfway. |
| `provision-*`, `luks-slots` | no | Chromebook installs are unencrypted ([0004](0004-image-and-install.md)), so owner setup has no staged unlock. They become required with the first boot package that owns one. |
| `update-takeover` | no | The boot chain writes a partition, not files a package could conflict with. |

### Upstream files changed

| File | Change |
| --- | --- |
| `bin/omarchy-hw-platform` | `google,` vendor → `aarch64-chromebook`, ahead of `qcom,`; contradictions with Apple, N1x, GB10; manifest name |
| `bin/omarchy-hw-aarch64-chromebook` | new family predicate, a copy of the Snapdragon one |
| `bin/omarchy-lifecycle-dispatch` | the two registrations and the comment explaining them |
| `bin/omarchy-pkg-defaults` | the platform's list |
| `install/omarchy-aarch64-chromebook.packages` | new: the two platform packages |
| `install/helpers/image-target.sh` | manifest name |
| `install/helpers/pacman.sh` | template directory, default channel edge |
| `default/pacman/aarch64-chromebook/` | new: edge `pacman.conf` and mirrorlist |
| `test/shell.d/{base,hw-platform,image-target-platform,lifecycle-dispatch,pacman-templates,platform-packages}-test.sh` | the cases above |
| `AGENTS.md`, `docs/file-layout.md`, `docs/lifecycle-dispatch.md` | the platform's name, detection and registration |

One more file outside `book/` belongs to the port, not to the registration: `.github/workflows/book-packages.yml`, which GitHub reads only from that directory ([0006](0006-package-repository.md)). It is a new file with a name upstream won't use, so it never conflicts.

### Going upstream

Everything above but the repository URL in `default/pacman/aarch64-chromebook/pacman-edge.conf` is board- and fork-agnostic. Once the platform packages have been Verified on a Chromebook, the registration goes to omacom/omarchy as one pull request. Merged, the fork stops carrying it, and the Chromebook repository stops needing its own build of the `omarchy` runtime ([0006](0006-package-repository.md)).

## Acceptance

1. On a Hayato booted from a card built by [0004](0004-image-and-install.md): `omarchy-hw-platform` prints `aarch64-chromebook`, and `omarchy-lifecycle-dispatch --resolve update-verify` prints `/usr/lib/omarchy/chromebook-boot/update-verify`.

## Tasks

- [x] Detector, predicate, manifest, package list, pacman templates, dispatch registration
- [x] Upstream tests extended; each new case fails with the change reverted
- [x] Docs
- [ ] Hardware acceptance
- [ ] Upstream pull request

## Verification

None yet.

## Changelog

- 2026-10-22: created and implemented.
