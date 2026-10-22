# Review of the source projects

What this port took from each project it builds on, what it left, and why. Written when the port started (2026-10-22), from these revisions:

| Project | Revision | What it is |
| --- | --- | --- |
| [Brunux/LazyOS](https://github.com/Brunux/LazyOS) | `0cd4e06` (2026-10-21, v0.3.0) | Debian forky for the Google Hayato, with a sway session. 0.7 GiB at an idle desktop. |
| [Brunux/omarchybook](https://github.com/Brunux/omarchybook) | `492eb28` (2026-10-18) | The first Omarchy port to the Hayato: Arch Linux ARM plus Omarchy 4. 1.6 GiB at an idle desktop. |
| [omacom/omarchy](https://github.com/omacom/omarchy) | `be54892` (`quattro`) | Upstream Omarchy, which this repository forks. |
| [omacom/omarchy-mac-pkgs](https://github.com/omacom/omarchy-mac-pkgs) | `c0356a2` | Apple Silicon's platform packages: the model for this port's. |
| [omacom/omarchy-iso](https://github.com/omacom/omarchy-iso) | `6569208` | The ISO, its configurator and its image tooling. |
| [omacom/omarchy-pkgs](https://github.com/omacom/omarchy-pkgs) | `de5c031` | The recipes for Omarchy's own packages. |
| [postmarketOS pmaports](https://gitlab.postmarketos.org/postmarketOS/pmaports) | `63713ff7` (`main`) | Where the board knowledge comes from ("Nura" in LazyOS' docs is this postmarketOS-based setup). |

## LazyOS

**What it got right.** It is the only one of the three that boots, installs and updates on the Hayato today, and its device layer is already the right shape: a board is `devices/<codename>/` with pmaports' `deviceinfo`, and names a kernel in `kernels/<flavor>/` (version, config, patch series). Its `lib-cgpt.sh` writes down every ChromeOS GPT pitfall it hit on this hardware (no `cgpt create -z`, parted for the protective MBR, partitions resolved by number and asserted by label, the 33 sectors of the backup GPT), and its `docs/optimization.md` measures every tuning it ships instead of guessing.

**Taken:**

- The board profile and the kernel (config, patches), byte for byte; they match pmaports except for the documented additions ([`kernels/mediatek-mt81/PROVENANCE.md`](../kernels/mediatek-mt81/PROVENANCE.md)).
- The kernel partition build: `depthchargectl build --root none --board … --compress lzma`, exactly as `make-kpart.sh` runs it.
- The GPT rules, in [`lib/layout.sh`](../packages/omarchy-chromebook-boot/lib/layout.sh).
- The chroot guard that compares `stat -L /` with `/proc/1/root`, and the `kern_guid=` lookup of the booted partition.
- The measured kernel tuning (MGLRU, schedutil, HZ=1000, dynamic preemption) and `transparent_hugepage=madvise`.
- The keyd map, by way of omarchybook.

**Left:**

- The Debian root filesystem, initramfs-tools and the sway session: this port is Omarchy.
- Writing the running kernel partition in place: one bad kernel needs a recovery card. Replaced by A/B writes ([decisions](decisions.md#ab-kernel-partitions)).
- Rewriting the partition by hand after a kernel update (`install-kpart.sh`): replaced by mkinitcpio's post hook.
- The separate 512 MiB ext2 `/boot` (copied from pmbootstrap): depthcharge never reads it.
- Emptying `machine-id` when cloning to the eMMC ([decisions](decisions.md#identity)).

## omarchybook

**What it got right.** It chose the architecture upstream would: a platform family with its own detection (`aarch64-google`), its boot operations behind `omarchy-lifecycle-dispatch`, and two platform packages split like Apple's (`omarchy-book-boot`, `omarchy-book`). It also did the hard Arch Linux ARM groundwork: a `depthcharge-tools` recipe that runs on Python 3.14, the vboot developer keys ALARM does not ship, an Arch kernel recipe, and the kernel options Omarchy's firewall and Bluetooth need.

**Why it was hard to use as a reference:**

- The platform registration was a 382-line patch applied to a pinned upstream checkout at build time, outside the tree it changed. Every upstream change could break it silently, and reading the port meant reading a diff of a diff.
- Code that runs on the device was split between `boot/` and `scripts/`, and staged into the packages from outside their directories (`extra.list`), so a package could not be built or tested on its own.
- There was no per-process memory measurement: its reports have `free -h` only, so the 1.6 GiB could not be broken down.

**Problems found while porting from it:**

- Its `video` group step (for backlight access) runs during the first boot's hardware setup, before owner setup has created the owner, so on an image it never applies. This port drops the step: Omarchy's brightness goes through `brightnessctl` and logind ([decisions](decisions.md#backlight)).
- `boot/devkeys/README.md` says the keys are passed with `--keydir`; its `make-kpart.sh` (the code it tested) correctly passes `--vboot-keyblock`, `--vboot-public-key` and `--vboot-private-key`, since `depthchargectl` has no `--keydir`. This port follows the code.

**Taken:** the `depthcharge-tools` recipe and its two patches ([`recipes/depthcharge-tools/PROVENANCE.md`](../recipes/depthcharge-tools/PROVENANCE.md)), the developer keys, the kernel `PKGBUILD`'s shape, the four kernel options, the keyd map, the key names and the journal cap.

## omacom

Upstream already has every seam this port needs, which is why so little of it lives outside `book/`:

| Seam | Where | Used for |
| --- | --- | --- |
| Platform detection | `bin/omarchy-hw-platform` | `google,` boards are `aarch64-chromebook` |
| Lifecycle dispatch | `bin/omarchy-lifecycle-dispatch`, `docs/lifecycle-dispatch.md` | boot setup, update verification, factory reset, system and user setup, through the platform packages |
| Image mode | `/var/lib/omarchy/image/target`, `install/helpers/image-target.sh` | hardware setup deferred to the board's first boot |
| Deferred provisioning | `omarchy-apply-system --defer-provisioning --first-install` | the owner wizard on first boot |
| Package composition | `bin/omarchy-pkg-defaults`, `install/omarchy-<platform>.packages` | the Chromebook's default set |
| Pacman templates | `install/helpers/pacman.sh`, `default/pacman/<platform>/` | the Chromebook repository first |
| Kernel command line | `/etc/limine-entry-tool.d/*.conf` | the kernel partition's command line, so Omarchy's boot fixes reach Chromebooks |
| mkinitcpio drop-ins | `/etc/mkinitcpio.conf.d/` | removing `autodetect` and `btrfs-overlayfs`, adding the board's modules |
| Platform root | `/usr/share/omarchy-platform/key-names` | the action row's legends in the keybindings menu |
| Shell plugins | `omarchy plugin disable`, `shell.json` | the lite profile's shell trim |
| User overrides | `~/.config/hypr/*.lua` | the lite profile's Hyprland changes |
| Toggles | `omarchy-toggle` | the crash watcher off |
| Input methods | `omarchy setup input <method>` | CJK input installed on demand |

From **omarchy-mac-pkgs**: the package contract (`install DESTDIR`, `test/all`, entrypoints installed where the dispatcher looks) and the split between a boot package and a runtime package. From **omarchy-iso**: the btrfs layout (label `OMARCHY`, `@ @home @log @pkg`, `noatime,compress=zstd`), the environment it gives `omarchy-apply-system`, the aarch64 package renames, the pinned Arch Linux ARM container its CI uses, and the image-sealing rule (an empty `machine-id`, never `uninitialized`, because a first boot applies presets that on Arch disable everything not listed). The ISO itself boots UEFI only, so it can never install a Chromebook. From **omarchy-pkgs**: the `omarchy-dev` and `omarchy-settings-dev` recipes, which take a local tree through `OMARCHY_SRC`; they are pinned to `be54892` (r7218), this fork's own base.

## postmarketOS

`device/community/device-google-asurada` and `device/community/linux-postmarketos-mediatek-mt81` (7.2.7) at `63713ff7`. Every file this port imported matches them byte for byte, except LazyOS' `transparent_hugepage=madvise` in `kernel-cmdline.conf` and the kernel config changes listed in its provenance. The import tool also shows what a second board brings: the Kukui depends on postmarketOS' own `alsa-ucm-conf-cros`, which Arch does not have.
