# 0005: Memory budget

Status: Accepted (the lite profile is implemented; the budget is verified on the first image)
Related: [`book/packages/omarchy-lite/`](../packages/omarchy-lite/), [`book/tools/memory-report`](../tools/memory-report), [`docs/omarchy-shell.md`](../../docs/omarchy-shell.md), [`plans/server.md`](../../plans/server.md) (editions), LazyOS [`docs/optimization.md`](https://github.com/Brunux/LazyOS/blob/main/docs/optimization.md)

## Problem

A Chromebook like the Hayato has 4 GB of RAM. omarchybook, a straight port of Omarchy 4 to it, used **1.6 GiB** at an idle desktop (`free -h`, used, `reports/2026-10-17-diagnostics-third-card.txt`). LazyOS on the same machine, Debian with sway and waybar, uses **0.7 GiB**. The target is **under 1 GiB** at an idle desktop, without leaving the Omarchy ecosystem: same shell, same commands, same themes, same updates.

There is no per-process measurement of omarchybook, so nobody knows yet where the 0.9 GiB difference goes. Guessing and replacing would be exactly the kind of change that costs a fork its mergeability for a saving nobody measured.

## Shape

1. **Measure first.** `book/tools/memory-report` on the same Hayato, under the same protocol, on LazyOS, on omarchybook's card and on this port's first image. One report each, kept in this spec.
2. **Spend the budget by size.** Work the list below from the biggest measured consumer down, and stop when the session is under budget.
3. **Use Omarchy's own knobs before changing anything of Omarchy's.** In order of preference: a setting the user or a platform package can set (disabled shell plugins, systemd presets and drop-ins, environment variables, kernel tuning); an upstream pull request that makes everyone lighter (socket activation, a wallpaper decoded at screen size); a package left out of the Chromebook's default set; and only last a replacement. Every replacement says why upstream couldn't take the fix, next to the code, as AGENTS.md asks.
4. **A profile, not a fork.** The savings that change behaviour (a disabled dock, input methods installed on demand) are a "lite" profile the Chromebook image applies, built so `plans/server.md`'s edition mechanism could carry it if upstream adopts that.

## The protocol

- The board: a Hayato (4 GB), its eMMC, the image under test, the default theme and wallpaper.
- Boot, log in, open nothing, wait **60 s** idle, then `sudo book/tools/memory-report > report.txt` from a TTY or SSH (not a terminal on the desktop, which would count itself).
- The budget is on **"Used (as free reports it)"** (`MemTotal − MemFree − Buffers − Cached − SReclaimable`), the number both earlier figures are in. The report also gives `MemTotal − MemAvailable`, the per-process PSS, the systemd units' cgroup memory, the GPU memory each DRM client holds, zram and tmpfs.
- Three runs, the median kept.

## Candidates

Ordered by expected size, from Omarchy's session definition (`default/hypr/autostart.lua`, `install/user/first-run/enable-user-units.sh`, `install/config/enable-services.sh`). Every number here is an estimate until a report replaces it.

| # | What | Why it is resident | Estimate | Levers, most upstream-friendly first |
| --- | --- | --- | --- | --- |
| 1 | **Quickshell** (the Omarchy shell: bar, menus, panels, notifications, lock, polkit, dock, wallpaper) | One Qt 6 QML process hosting 140 QML files; first-party services load at startup, each layer surface has its own window and GL buffers | 250-450 MiB | `MALLOC_ARENA_MAX=2` (glibc arenas in a threaded Qt app); `QSG_RENDER_LOOP=basic` (one render thread instead of one per window); disable plugins a Chromebook session doesn't need through `shell.json`'s `disabledPlugins` (the dock, the agents panel); the wallpaper decoded at the panel's size (1366x912 here) rather than the theme's, as an upstream fix |
| 2 | **Hyprland** | The compositor; blur, shadows and animations allocate their own framebuffers | 100-180 MiB with GPU buffers | decoration settings for panfrost (blur off or fewer passes), the way LazyOS measured swayfx's blur; `misc:vfr` |
| 3 | **fcitx5** with Chinese, Japanese, Korean and table add-ons | Enabled for every user at first run; it also turns Omarchy's XCompose sequences into text, so it can't simply go | 60-150 MiB | install the CJK add-ons on demand (the profile drops them from the default set, an `omarchy-install-` command adds them back), keep fcitx5 itself for compose |
| 4 | **The audio stack** (PipeWire, pipewire-pulse, WirePlumber) | Always on | 30-60 MiB | WirePlumber's Lua scripts: measure first |
| 5 | **udiskie** | A Python automounter in autostart | 30-45 MiB | an upstream change to make it a user unit that can be disabled; or leave automounting to the file manager |
| 6 | **System services**: cups, avahi, NetworkManager, bluetooth, power-profiles-daemon, systemd-resolved, systemd-oomd, sddm | Enabled by install | 60-100 MiB together | `cups.socket` instead of `cups.service` (an upstream PR: printers are rare and CUPS starts on first use); avahi's socket |
| 7 | **Smaller user daemons**: `owed` (the video-wallpaper policy daemon, resident even for a still wallpaper), `omarchy-crash-watch` (a `journalctl -f` follower), `bt-agent`, gnome-keyring, xdg-desktop-portal(-gtk, -hyprland), `omarchy-hyprland-monitor-watch` | Enabled at first run or started by D-Bus | 40-80 MiB together | `omarchy-toggle-crash-capture` exists already; `owed` only while a moving wallpaper is set (an upstream suggestion to owe) |
| 8 | **Kernel and tmpfs**: slab, page tables, CMA, the GPU's carve-outs, `/tmp` and `/run` | Always | measured by the report | kernel config ([0002](0002-devices-and-kernels.md)); journald's runtime journal |

What LazyOS already showed on this hardware, and this port already has: MGLRU, `transparent_hugepage=madvise`, zram with zstd at the size of RAM (Omarchy's own default), systemd-oomd, a capped journal.

## Decisions (2026-10-22, the maintainer)

- **The budget is the idle desktop**, measured with `free`'s "used" as in the protocol. A working session (Chromium and friends) is out of scope for now.
- **The lite profile is on by default on Chromebooks**, and built as an opt-in profile any Omarchy machine can use.
- **It may make all four kinds of change** proposed: trim the shell, install CJK input on demand, lighter Hyprland effects, fewer always-on services. **And replace the file manager**: PCManFM instead of Nautilus, "for now".
- **No measurement first**: build the profile from the estimates above, and measure once this port's first image boots. The candidates table stays the plan of record until then.

## The lite profile

`omarchy-lite` ([`book/packages/omarchy-lite/`](../packages/omarchy-lite/)), applied on a Chromebook by `omarchy-chromebook`'s `setup-system` and `setup-user` whenever it is installed, and built into card images by default (`build-image --profile lite`). Elsewhere, `omarchy-lite enable`.

| Change | Candidate | Through | Upstream file edited |
| --- | --- | --- | --- |
| The dock and the agents widget off | 1 | `omarchy plugin disable` (or `shell.json`, as the shell's `setEnabled` writes it, when no shell is running) | none |
| `MALLOC_ARENA_MAX=2` for the session | 1 | `/usr/lib/environment.d/60-omarchy-lite.conf` | none |
| Hyprland animations off (blur and shadows are already off in Omarchy's defaults) | 2 | a marked block in `~/.config/hypr/looknfeel.lua` | none |
| CJK input methods not installed | 3 | `share/subtract.packages`; `omarchy setup input <method>` installs one on demand, as it already does | none |
| udiskie not installed | 5 | `share/subtract.packages` | none |
| CUPS and avahi on their sockets | 6 | `systemctl disable <service>`, `enable <socket>`, once | none |
| The crash watcher off | 7 | `omarchy-toggle crash-capture-off on` | none |
| PCManFM instead of Nautilus (and Nautilus' localsearch indexer gone with it) | file manager | `share/subtract.packages` and `add.packages`; a marked block in `~/.config/hypr/bindings.lua`; `xdg-mime default pcmanfm.desktop inode/directory` | none |

Two candidates are left for after the measurement: `QSG_RENDER_LOOP=basic` (it changes every Qt Quick app's rendering, so it has to earn its place in numbers), and the wallpaper decoded at the panel's size (an upstream change).

Known costs, accepted: with udiskie gone, Omarchy's autostart line for it fails quietly at each login (one journal line), and removable media mount when PCManFM is asked to, not on insertion. Upstream candidates that would remove both: making udiskie a user unit that can be disabled, and an `omarchy-launch-file-manager` that honours the default file manager the way `omarchy-launch-browser` honours the default browser.

## Requirements

- **R5.1** `memory-report` runs unchanged on this port, omarchybook and LazyOS, and reports the budget's number. *Check:* the reports in Verification.
- **R5.2** An idle Omarchy desktop on a 4 GB Chromebook, lite profile on, stays under 1024 MiB "used". *Check:* the protocol, median of three.
- **R5.3** Every lite change goes through a setting, a package list or a user override file; no upstream file is edited for it. *Check:* the table above; `git diff --stat upstream/quattro` ([0007](0007-upstream-sync.md)).
- **R5.4** Without a running shell, the lite profile changes `shell.json` exactly as the shell's own `setEnabled` does: a bar widget leaves the bar, a first-party service goes into `disabledPlugins[]`. *Check:* `book/packages/omarchy-lite/test/all`.
- **R5.5** Each lite step runs once; a change the owner reverts (a deleted override block, a re-enabled plugin or service) is never reapplied. *Check:* the same test.
- **R5.6** `build-image --profile lite` leaves `subtract.packages` out of the default set, adds `add.packages` and `omarchy-lite`, applies the system half after Omarchy's own setup, and warns when a subtracted name is no longer in the default set. *Check:* the build log.

## Tasks

- [x] `memory-report`
- [x] `omarchy-lite`, applied by the Chromebook platform's setup operations, built into images
- [ ] First measurement on the Hayato, lite profile on and off
- [ ] The two measured candidates (`QSG_RENDER_LOOP`, the wallpaper's decode size)
- [ ] Upstream pull requests: socket-activated CUPS, a user unit for udiskie, `omarchy-launch-file-manager`

## Verification

| Date | System | Used | Total − Available | Report |
| --- | --- | --- | --- | --- |
| 2026-10-17 | omarchybook, third card | 1.6 GiB | — | `free -h` only |
| — | LazyOS v0.3.0 | 0.7 GiB (reported by the maintainer) | — | to run |
| — | this port, first image | — | — | to run |

## Changelog

- 2026-10-22: created as a draft, with the protocol, the tool and the candidates.
- 2026-10-22: accepted with the maintainer's decisions; the lite profile implemented.
