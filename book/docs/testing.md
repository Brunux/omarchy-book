# Testing

How to test the port, and what has been tested so far. The short version: everything that can be proven off-device is, and nothing has yet run on a Chromebook.

## Running the tests

```bash
book/packages/omarchy-chromebook-boot/test/all
book/packages/omarchy-chromebook/test/all
book/packages/omarchy-lite/test/all
book/tools/check-devices

# Upstream's tests that the platform registration lives in
for t in hw-platform image-target-platform lifecycle-dispatch pacman-templates platform-packages platform-setup; do
  bash test/shell.d/$t-test.sh >/tmp/$t.log 2>&1 || echo "FAIL $t (see /tmp/$t.log)"
done
```

Two things to know:

- **Run them as an ordinary user.** As root, Omarchy's platform detector ignores fixture roots on purpose (no environment variable may choose what root runs), so upstream's platform tests skip their fixtures and the boot package's fixture tests skip themselves. A root run that "passes" has tested very little. In a container that only has root: `useradd -m tester` and `runuser -u tester -- <command>`.
- **`pacman-conf` is needed** by `pacman-templates-test.sh`. On Arch it comes with pacman; on Debian or Ubuntu, `apt-get install pacman-package-manager`.

The CI workflow runs all of the above on every push that touches `book/` ([0006](../specs/0006-package-repository.md)).

## How the package tests work

They run the real commands against fixtures, so they test the logic rather than a stub of it:

- **The boot package** gets a fixture machine: a target root staged by the package's own `install`, a live view (`/proc/cmdline` with `kern_guid=`, the device tree's `compatible`, `/proc/1/root` pointing at `/` for a booted machine or elsewhere for a chroot), and a disk whose partitions are plain files. Stand-ins for `cgpt`, `lsblk`, `findfs`, `blockdev`, `depthchargectl` and `futility` keep the partition flags in files and write an "image" that changes with every input. The command reads the fixture live view only when not root (`OMARCHY_CHROMEBOOK_PROC`), as Omarchy's detector does.
- **The runtime and lite packages** run their commands with stand-ins for `systemctl`, `xdg-mime`, `omarchy-toggle`, `omarchy-shell` and `omarchy-plugin-disable`, against a fixture home with Omarchy's stock `shell.json`.

## What has been verified (2026-10-22)

### Off-device: passing

| Suite | Tests | What they cover |
| --- | --- | --- |
| `omarchy-chromebook-boot` `device-test.sh` | 4 | board picked by the most specific device-tree name, whatever order profiles sort in; an unknown board and a SoC-only tree refused; configured board vs live tree; chroot uses the configuration; `deviceinfo` never executed |
| `cmdline-test.sh` | 4 | board, then Omarchy's drop-ins in name order, then the root from fstab; `/etc/default/limine` first; an untrusted drop-in fails the build; fstab without `/` fails |
| `write-test.sh` | 12 | A/B write, one try, running partition untouched; verify; idempotence; bless; alternation; a spent try is not "next"; corrupted bytes caught; in-place with backup; chroot and non-depthcharge refusal; post hook only for the board's kernel; futility rejection; `write-disk`; `setup-boot` on first boot and after |
| `install-test.sh` | 3 | what `install` stages; refusals; the mkinitcpio drop-in against Omarchy's HOOKS line |
| `layout-test.sh` | 3 | GPT geometry from `deviceinfo`, the backup GPT left whole, a too-small disk refused, the ISO's fstab |
| `omarchy-chromebook` | 5 | keyd's exclusions before the built-in keyboard; key-names format; keyd enabled once; the lite profile run when installed; install |
| `omarchy-lite` | 6 | `shell.json` changed as the shell's `setEnabled` does; Hyprland blocks, file manager, crash watcher; each step once, the owner's undo kept; the shell's own command when it runs; CUPS and avahi sockets once; install |
| `book/tools/check-devices` | — | `google-asurada` and `mediatek-mt81` pass; injected mistakes (a SoC claimed, a wrong codename) are reported |
| upstream `hw-platform` | 15 | including Hayato, Krane and Lazor (a Snapdragon Chromebook), Apple/Google and N1x/Google contradictions, the family predicate |
| upstream `image-target-platform` | 47 | including a Chromebook image built on another host |
| upstream `lifecycle-dispatch` | 18 | including the Chromebook registration and Mac entrypoints never running on a Chromebook |
| upstream `pacman-templates` | 11 | including the Chromebook's edge-only templates and repository order |
| upstream `platform-packages` | 10 | including the Chromebook list joining only its own set |
| upstream `platform-setup` | 6 | unchanged, still passing |

### Checks that the tests test something

- With the registration reverted, `hw-platform`, `image-target-platform` and `lifecycle-dispatch` fail on the new cases.
- In the boot package: giving the new partition no try instead of one, and removing the chroot guard, each turn a test red. Matching profile-first instead of token-first first went unnoticed; a test was added that catches it (a SKU profile sorting after its board's).
- The Lua the lite profile appends to `~/.config/hypr/` parses with `luac5.4 -p`.
- shellcheck reports nothing on any script, with four rules excluded on purpose: SC1090/SC1091 (modules sourced by computed path), SC2154/SC2034 (globals shared between the boot package's modules).

### Checked against live sources

- `book/tools/pmaports-import` against pmaports `main` (`63713ff7`): the board and kernel report no drift apart from the documented changes, and a new board (`google-kukui`, in a scratch copy) is imported and then refused by `check-devices` until its TODOs are filled in.
- `book/tools/memory-report` ran end to end on a Linux machine (not a Chromebook, so no zram or GPU rows).

### Not run yet

- `book/tools/build-packages` and the workflow's build job (need Arch Linux ARM), so no package has been built.
- `book/tools/build-image` (needs Arch Linux ARM, loop devices and the packages).
- Anything on a Chromebook: every spec's Acceptance section is open.

### Known failure, not caused by this port

`./test/cli` fails "theme template mix helper works" on this fork's base (`be54892`, unmodified) as well as with the port, in the environment the port was built in. It is left alone, as the root `AGENTS.md` asks for failures in untouched files.

## Working in a fresh clone

A clone made with `--depth 1` (or `--single-branch`) fetches only `quattro`, so git keeps no tracking branch for `chromebook-platform` and tools report its commits as unpushed even when they are on GitHub. Track it with:

```bash
git config --add remote.origin.fetch '+refs/heads/chromebook-platform:refs/remotes/origin/chromebook-platform'
git fetch origin chromebook-platform
git branch -u origin/chromebook-platform
```
