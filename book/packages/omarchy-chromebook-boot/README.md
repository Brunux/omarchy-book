# omarchy-chromebook-boot

The boot chain of ARM Chromebooks for Omarchy. A Chromebook's firmware, depthcharge, loads a signed FIT image (kernel, initramfs, device trees, command line) from a ChromeOS kernel partition, so a kernel installed in `/boot` boots nothing until that partition is rewritten. This package rewrites it, safely, every time the initramfs is built. The design and its requirements are [book/specs/0003-boot-package.md](../../specs/0003-boot-package.md).

## What it installs

| Path | What |
| --- | --- |
| `/usr/bin/omarchy-chromebook-boot` | The command everything else runs (below). Its modules are in `/usr/lib/omarchy-chromebook-boot/lib/`. |
| `/usr/lib/omarchy/chromebook-boot/{setup-boot,update-verify}` | The entrypoints `omarchy-lifecycle-dispatch` runs on `aarch64-chromebook`. |
| `/usr/lib/initcpio/post/omarchy-chromebook-kpart` | mkinitcpio's post hook: after the board's initramfs is built, write the kernel partition. |
| `/etc/mkinitcpio.conf.d/50-omarchy-chromebook.conf` | Drops `autodetect` (an image is built on another machine) and `btrfs-overlayfs` (no Limine snapshot entries) from Omarchy's hooks. |
| `/usr/lib/systemd/system/omarchy-chromebook-bless.service` | Marks the running kernel partition successful once the system is up. |
| `/usr/share/omarchy-chromebook-boot/devices/<codename>/` | The board profiles, from `book/devices`. |
| `/usr/share/omarchy-chromebook-boot/devkeys/` | ChromiumOS' public developer keys ([devkeys/README.md](devkeys/README.md)). |

On the machine it keeps `/etc/omarchy-chromebook/device` (the board's codename), `/etc/mkinitcpio.conf.d/60-omarchy-chromebook-device.conf` (the board's early modules) and `/var/lib/omarchy-chromebook-boot/partitions/<partuuid>` (what each kernel partition was built from).

## The command

```
omarchy-chromebook-boot status        # board, kernel partitions, what boots next
omarchy-chromebook-boot verify        # is the partition booting next current?
sudo omarchy-chromebook-boot write    # rebuild and write it now
omarchy-chromebook-boot cmdline       # the command line a partition gets
```

`write` builds the kernel partition from the running system and writes it to the kernel partition that is **not** running, makes that one the highest priority with a single try, and leaves the running one as it is. If the new kernel boots, `omarchy-chromebook-bless.service` marks it successful; if it does not, depthcharge falls back to the previous partition on the next power-on, by itself. A disk with one kernel partition (LazyOS' and postmarketOS' layout) is written in place, with its previous contents saved in `/var/lib/omarchy-chromebook-boot/`.

`write-disk --disk DISK --root DIR` is for image builds and installs: it writes every kernel partition of a new disk from the system mounted at `DIR`.

## Where the command line comes from

1. The board's `kernel-cmdline.conf`.
2. Omarchy's `KERNEL_CMDLINE[default]` from `/etc/default/limine` and `/etc/limine-entry-tool.d/*.conf`, the same files the Limine path reads on every other platform, so Omarchy's boot settings and a hardware leaf's quirks reach a Chromebook too.
3. `root=` and `rootflags=subvol=` from the `/` entry of `/etc/fstab`.

## Tests

```bash
test/all
```

They run the real command against a fixture disk (fake `cgpt`, `lsblk`, `blockdev`, `findfs`, `depthchargectl` and `futility` over plain files), so they prove the logic: board resolution, the command line, A/B selection and flags, records and verification. Writing a real kernel partition is proven only on a Chromebook (spec 0003, Acceptance).
