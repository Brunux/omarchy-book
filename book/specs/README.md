# Specs

This port is built spec-first. A spec says what problem a feature solves, what was decided and what was rejected, what exactly must be true when it is done (numbered requirements), and how that is checked. Code is written against an accepted spec; a spec is finished when its checks have passed on hardware.

The format extends upstream's [`plans/`](../../plans/) (Problem, Shape, Rejected approaches, Design) with the parts that make a spec testable, so it reads like the rest of Omarchy and costs upstream nothing: specs live in `book/specs/`, which upstream never touches.

## Lifecycle

| Status | Means | Who moves it |
| --- | --- | --- |
| **Draft** | Open for discussion. Decisions may change. | Anyone |
| **Accepted** | The maintainer agreed to the decisions. Code may land against it. | Maintainer |
| **Implemented** | Every requirement has code and an off-device test, or says why it can't. | The implementing commit |
| **Verified** | The acceptance checks passed on hardware; the report is in the spec's Verification section. | After a hardware run |
| **Superseded** | Replaced by a later spec, which it links. | The replacing commit |

A change of decision after Accepted is made in the spec, in the same commit as the code that follows it, and noted in the spec's Changelog.

## Writing one

Copy [`0000-template.md`](0000-template.md) to the next free number. Requirements are numbered `R<spec>.<n>` (for example `R3.4`) and written so a check can fail: "the kpart is written to the kernel partition that is not running", not "updates are safe". Each requirement names how it is checked: an off-device test (a path under `book/`), a command to run on the device, or both. Commits that implement requirements name them in the message body (`Implements R3.4, R3.5.`).

## Index

| # | Spec | Status |
| --- | --- | --- |
| 0001 | [Platform registration](0001-platform-registration.md): `aarch64-chromebook` in upstream's seams, and the rules for touching upstream files | Implemented |
| 0002 | [Devices and kernels](0002-devices-and-kernels.md): the board and kernel model, imported from pmaports | Implemented |
| 0003 | [Boot package](0003-boot-package.md): `omarchy-chromebook-boot`, the kernel partition, A/B kernel updates | Implemented |
| 0004 | [Image and install](0004-image-and-install.md): the card image, first boot, and installing to internal storage | Implemented |
| 0005 | [Memory budget](0005-memory-budget.md): an idle desktop under 1 GiB, and the lite profile | Implemented (budget unmeasured) |
| 0006 | [Package repository](0006-package-repository.md): building and publishing the packages | Draft |
| 0007 | [Upstream sync](0007-upstream-sync.md): merging omacom/omarchy and what a merge must check | Accepted |

"Implemented" means written and tested off-device. Nothing here is Verified until it has run on a Chromebook.
