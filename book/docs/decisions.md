# Decisions

Every decision behind the port in one place: what was chosen, over what, and where its full reasoning is. "Maintainer" decisions were asked and answered; the rest were made while building and can be revisited the same way, by changing the spec that owns them.

## Made by the maintainer (2026-10-22)

### Where the port lives

**In this fork, in `book/`**, laid out like omarchy-mac-pkgs so it can move to a repository of its own later, rather than a separate `omarchy-book-pkgs` repository from the start. Upstream never touches `book/`, so merges stay cheap. [book/README.md](../README.md), [0007](../specs/0007-upstream-sync.md)

### The platform's name

**`aarch64-chromebook`**, with packages `omarchy-chromebook` and `omarchy-chromebook-boot`, rather than omarchybook's `aarch64-google`. The family is defined by the boot chain (depthcharge), not the vendor. [0001](../specs/0001-platform-registration.md#rejected-approaches)

### What v1 installs

**A card image with a btrfs root and no disk encryption.** LUKS comes as its own spec, because the unlock key would have to live inside the signed kernel partition until owner setup re-keys it. [0004](../specs/0004-image-and-install.md#rejected-approaches)

### Where packages come from

**GitHub Actions on free arm64 runners, published as GitHub release assets** (the way Asahi ALARM publishes), signed. [0006](../specs/0006-package-repository.md)

### The memory work

- **The budget is the idle desktop**: under 1 GiB "used" as `free` reports it, 60 s after login.
- **The lite profile is on by default on Chromebooks**, built as an opt-in profile any Omarchy machine can use.
- **It may trim the shell, install CJK input on demand, lighten Hyprland's effects, reduce always-on services, and replace Nautilus with PCManFM** ("for now").
- **No measurement before building it**: build from estimates, measure on the first image.

[0005](../specs/0005-memory-budget.md#decisions-2026-10-22-the-maintainer)

## Made while building

### A/B kernel partitions

Two ChromeOS kernel partitions. An update writes the one not running, makes it boot next with **one try**, and a boot service marks it successful once the system is up. A kernel that does not boot falls back to the previous one at the next power-on, with no card. Chosen over writing the running partition in place (LazyOS, omarchybook, postmarketOS), where one bad kernel needs a recovery card. A disk with one kernel partition is still written in place, with a backup. [0003](../specs/0003-boot-package.md#rejected-approaches)

### No separate /boot

The kernel and initramfs live in the btrfs root, inside its snapshots, as on every Omarchy install. depthcharge reads only the kernel partitions, so pmbootstrap's 512 MiB ext2 `/boot` bought nothing. [0004](../specs/0004-image-and-install.md#the-layout)

### What triggers a write

**mkinitcpio's post hook** (`/usr/lib/initcpio/post/`), rather than a pacman hook on the kernel package. Omarchy's first-boot hardware setup runs `mkinitcpio -P` directly, which fires no pacman hook; the post hook runs after every initramfs build, whoever asked. [0003](../specs/0003-boot-package.md#rejected-approaches)

### depthchargectl build, cgpt for the rest

`depthchargectl build` (the step LazyOS proved on the Hayato) builds the image; the boot package picks the partition, sets the flags with `cgpt`, and records what it wrote. Not `depthchargectl write`/`bless`, whose own rules for the target and command line would not match what `update-verify` checks. [0003](../specs/0003-boot-package.md#rejected-approaches)

### The kernel command line

The board's `kernel-cmdline.conf`, then Omarchy's `KERNEL_CMDLINE[default]` from `/etc/default/limine` and `/etc/limine-entry-tool.d/*.conf` (the files Omarchy and its hardware leaves already write on every platform), then the root from `/etc/fstab`. One place to configure it, the same as everyone else's, and upstream's boot fixes (`initramfs_async=0`, `systemd.tty.term.console=dumb`) arrive by themselves. [0003](../specs/0003-boot-package.md#requirements)

### Board profiles are data

`deviceinfo` is parsed, never sourced (the boot package reads it as root). A board is picked by the most specific device-tree name any profile claims, and a profile may never claim a SoC (`mediatek,mt8192` names a dozen different Chromebooks). [0002](../specs/0002-devices-and-kernels.md#rejected-approaches)

### Which dispatch operations are required

`setup-boot`, `update-verify` and the four factory-reset operations are required; provisioning, `luks-slots` and `update-takeover` are optional. Until the reset operations ship, a factory reset on a Chromebook **refuses before changing anything**, naming the boot package, instead of rebuilding Limine UKIs the machine does not boot. [0001](../specs/0001-platform-registration.md#why-these-operations-are-required)

### The initramfs

The boot package's mkinitcpio drop-in removes `autodetect` (an image is built on another machine, and the kernel partition's initramfs is the only one the board has) and `btrfs-overlayfs` (it boots Limine's snapshot entries and ships with limine-snapper-sync). The board's early modules are added from its profile. [0003](../specs/0003-boot-package.md#requirements)

### Backlight

**No udev rule and no `video` group.** Omarchy's brightness keys go through `brightnessctl`, which works through logind from the session on every other laptop. If it does not on a Chromebook, that is a bug to fix where it lives. omarchybook's version also ran before the owner existed on an image's first boot. Checked on hardware in [0003](../specs/0003-boot-package.md#acceptance), acceptance 5.

### Identity

**A card image is sealed** (empty `machine-id`, never `uninitialized`; no D-Bus id, no SSH host keys), because every card flashed from it is a new machine. **`install-internal` keeps the identity**, because moving to the eMMC is the same machine, and an emptied `machine-id` on an installed system invites the first-boot preset handling that on Arch disables everything not listed. [0004](../specs/0004-image-and-install.md#rejected-approaches)

### The Omarchy runtime

Until upstream merges the registration, the Chromebook repository carries its own `omarchy-dev` and `omarchy-settings-dev`, built from this checkout with upstream's own recipes (`OMARCHY_SRC`), versioned with upstream's scheme (`4.0.0.r<commits>.g<hash>`), and the Chromebook pacman template searches that repository first. Edge only, like Apple Silicon. [0006](../specs/0006-package-repository.md), [0001](../specs/0001-platform-registration.md)

### How the lite profile is applied

Through knobs Omarchy already has, never by editing an upstream file: `omarchy plugin disable` (or `shell.json`, written the way the shell's `setEnabled` writes it), marked blocks in `~/.config/hypr/*.lua`, `omarchy-toggle`, systemd sockets, `environment.d`, and package lists the image builder applies. On a Chromebook, `omarchy-chromebook`'s `setup-system` and `setup-user` run it, since `setup-user` runs at user setup, before the first session. Each step runs once, so what the owner reverts stays reverted. [0005](../specs/0005-memory-budget.md#the-lite-profile)

### MALLOC_ARENA_MAX now, QSG_RENDER_LOOP later

`MALLOC_ARENA_MAX=2` for the session (a known saving for threaded glibc programs like a Qt shell). `QSG_RENDER_LOOP=basic` waits for a measurement, since it changes every Qt Quick app's rendering. [0005](../specs/0005-memory-budget.md#the-lite-profile)

### Specs

The spec format extends upstream's `plans/` (Problem, Shape, Rejected approaches, Design) with numbered requirements, checks and acceptance, so it reads like the rest of Omarchy and costs upstream nothing. [specs/README.md](../specs/README.md)
