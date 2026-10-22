# omarchy-chromebook

The runtime half of ARM Chromebook support for Omarchy, beside the boot chain in [`omarchy-chromebook-boot`](../omarchy-chromebook-boot/). It owns the platform root (`/usr/share/omarchy-platform/`), so it conflicts with any other platform package.

| Path | What |
| --- | --- |
| `/usr/lib/omarchy/chromebook/setup-system` | The entrypoint `omarchy-lifecycle-dispatch setup-system` runs on `aarch64-chromebook`: enables keyd, once, and applies the lite profile's system half when `omarchy-lite` is installed. |
| `/usr/bin/omarchy-chromebook-setup-system` | The work behind it, runnable by hand. |
| `/usr/lib/omarchy/chromebook/setup-user` | The entrypoint `omarchy-lifecycle-dispatch setup-user` runs, as the user: the lite profile's user half when [`omarchy-lite`](../omarchy-lite/) is installed. |
| `/etc/keyd/default.conf` | The action row stays the action row; Search plus the top row gives F1-F10, Ctrl+Alt plus it a virtual console. The built-in keyboard's power button, lid switch and headset jack are excluded from keyd, or logind would stop seeing them. |
| `/usr/share/omarchy-platform/key-names` | The action-row legends for the keybindings menu (brightness on F6/F7, volume on F8-F10). |
| `/usr/lib/systemd/journald.conf.d/10-omarchy-chromebook.conf` | Caps the journal at 200 MiB on eMMC. |

What it deliberately does not do: grant backlight access with a udev rule or the `video` group. Omarchy's brightness keys go through `brightnessctl`, which works through logind from the user's session on every other laptop; if it does not on a Chromebook, that is a bug to fix where it is, recorded in [book/specs/0003](../../specs/0003-boot-package.md) under hardware checks.

## Tests

```bash
test/all
```
