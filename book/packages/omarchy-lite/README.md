# omarchy-lite

The lite profile: the same Omarchy desktop, with less resident at an idle desktop, for machines like a 4 GB Chromebook. Every change goes through a knob Omarchy already has, and each can be undone on its own. The reasons and the budget are in [book/specs/0005-memory-budget.md](../../specs/0005-memory-budget.md).

| Change | How | Undo |
| --- | --- | --- |
| CUPS and avahi start on first use | `systemctl disable <service>`, `enable <service>.socket` | enable the service again |
| The shell's dock and agents widget are off | `omarchy plugin disable`, or `shell.json` the same way when the shell isn't running | `omarchy plugin enable omarchy.dock` |
| Hyprland animations are off | a marked block in `~/.config/hypr/looknfeel.lua` | delete the block |
| PCManFM is the file manager (Super+Shift+F, folders) | a marked block in `~/.config/hypr/bindings.lua`, `xdg-mime default pcmanfm.desktop inode/directory` | delete the block, set Nautilus back with `xdg-mime` |
| The crash watcher is off | `omarchy-toggle crash-capture-off on` | `omarchy-toggle-crash-capture` |
| `MALLOC_ARENA_MAX=2` for the session | `/usr/lib/environment.d/60-omarchy-lite.conf` | `MALLOC_ARENA_MAX=` in `~/.config/environment.d/` |
| Nautilus, the CJK input methods and udiskie are not installed; PCManFM is | `share/subtract.packages`, `share/add.packages`, applied by the image builder | `omarchy setup input <method>` for an input method; `omarchy-pkg-add` for the rest |

```bash
omarchy-lite enable                    # on any Omarchy machine
omarchy-lite enable --remove-packages  # and remove what subtract.packages lists
omarchy-lite status
```

On a Chromebook, `omarchy-chromebook` applies it through `setup-system` and `setup-user` whenever this package is installed, which card images do by default.

Each step runs once and leaves a marker (`/var/lib/omarchy-lite/`, `~/.local/state/omarchy-lite/`), so a change the owner reverts stays reverted.
