# Roadmap

What happens next, everything still open, and what is known not to work yet. Each item links the spec that owns it; this page collects them so nothing lives only in a task list.

## Next steps, in order

| # | Step | Who | Unblocks | Spec |
| --- | --- | --- | --- | --- |
| 1 | Review and merge the `chromebook-platform` branch into `quattro` | maintainer | the workflow can be run by hand | [0007](../specs/0007-upstream-sync.md) |
| 2 | Create the repository's signing key: the `BOOK_SIGNING_KEY` secret and `book/keys/omarchy-book.gpg` | maintainer | signed packages | [building](building.md#on-github-the-normal-way) |
| 3 | Run the **Book packages** workflow with build and publish | maintainer | the packages exist; images can be built | [0006](../specs/0006-package-repository.md) |
| 4 | Build an image on Arch Linux ARM: `sudo book/tools/build-image --device google-asurada` | maintainer | a card to boot | [0004](../specs/0004-image-and-install.md) |
| 5 | Boot it on the Hayato and work through the acceptance checks, one risky change per boot | maintainer | Verified specs | [0003](../specs/0003-boot-package.md#acceptance), [0004](../specs/0004-image-and-install.md#acceptance) |
| 6 | Measure the idle desktop with `sudo book/tools/memory-report`, lite profile on and off (and on omarchybook and LazyOS for comparison) | maintainer | the budget decided by numbers | [0005](../specs/0005-memory-budget.md#the-protocol) |
| 7 | Fix what the hardware run finds, record each run in its spec's Verification section | either | — | all |

## Open work by spec

**[0001](../specs/0001-platform-registration.md) Platform registration**
- Hardware acceptance.
- The pull request to omacom/omarchy, once the packages are Verified on a Chromebook.

**[0002](../specs/0002-devices-and-kernels.md) Devices and kernels**
- Build `linux-book-mediatek-mt81` on Arch Linux ARM; its `olddefconfig` diff must be empty apart from compiler symbols.
- Hardware acceptance.
- More boards: `book/tools/pmaports-import device <codename>`. The Kukui needs a recipe for postmarketOS' `alsa-ucm-conf-cros` first.

**[0003](../specs/0003-boot-package.md) Boot package**
- Hardware acceptance (six checks, the A/B fallback among them).
- The factory reset operations (`reset-prepare`, `reset-verify`, `reset-commit`, `reset-rollback`). Until then a factory reset on a Chromebook refuses before changing anything.
- Keep the previous kernel's modules until the new kernel is blessed (run `linux-modules-cleanup` from the bless service), so a fallback boot has all its modules.
- keyd's exclusion ids for boards other than the Hayato (they hash device names; `keyd monitor` on each new board).

**[0004](../specs/0004-image-and-install.md) Image and install**
- The first image build.
- Hardware acceptance, the eMMC install included.
- Grow the root partition to the card on first boot (see Known limitations).
- LUKS, as its own spec: the staged key in the kernel partition's initramfs until owner setup re-keys and rewrites both partitions.

**[0005](../specs/0005-memory-budget.md) Memory budget**
- The first measurement, lite profile on and off.
- The two candidates that wait for numbers: `QSG_RENDER_LOOP=basic`, and the wallpaper decoded at the panel's size.

**[0006](../specs/0006-package-repository.md) Package repository**
- The signing key, the first build and publish.
- `omarchy-book-keyring`, so the repository key reaches machines as an update.
- Build the image in the workflow too, and attach it to a release.

## Upstream pull request candidates

Changes that would help every Omarchy user and let the fork carry less. None is made in the fork; each would be proposed to omacom/omarchy (or to owe) on its own.

| Change | Why | Lets the fork drop |
| --- | --- | --- |
| The `aarch64-chromebook` registration ([0001](../specs/0001-platform-registration.md#going-upstream)) | Chromebooks work with stock Omarchy | the 18 changed upstream files and the forked runtime build |
| `cups.socket` instead of `cups.service` | printers are rare; CUPS starts on first use | the lite profile's CUPS step |
| udiskie as a user unit that can be disabled, instead of an autostart line | automounting becomes a choice | the failing autostart line on lite machines |
| `omarchy-launch-file-manager`, honouring the default file manager the way `omarchy-launch-browser` honours the default browser | any file manager without rebinding keys | the lite profile's bindings block |
| The wallpaper decoded at the screen's size in the shell | a 4K wallpaper costs a 4K bitmap on every screen | — (after measurement) |
| `owed` running only while a moving wallpaper is set (owe) | a resident daemon for a still image | — (after measurement) |

## Known limitations

- **Nothing has run on hardware yet.** Every spec is Implemented at most, none Verified ([testing](testing.md#what-has-been-verified-2026-10-22)).
- **The package repository is not published**, so images can only be built with `--repo` from a local `build-packages` run until step 3.
- **The image's root partition is fixed at `--size`** (8 GiB by default). A larger card keeps the rest unused, and nothing grows the partition yet (`cgpt add -i 3 -s <sectors>` plus `btrfs filesystem resize max /` would). `install-internal` fills the eMMC.
- **No disk encryption** on Chromebooks yet (decided for v1).
- **Factory reset refuses** on Chromebooks until the boot package implements its operations.
- **On the lite profile**, Omarchy's autostart line for udiskie fails quietly at each login (one journal line), and removable media mount when PCManFM opens them rather than on insertion.
- **A fallback boot may lack modules**: if the new kernel got far enough to run `linux-modules-cleanup` before failing, the previous kernel comes up with only its initramfs' modules, enough to repair.
- **One board.** `google-asurada` (Hayato, Spherion) is the only profile so far.
