# Omarchy on a Chromebook

How to put Omarchy on an ARM Chromebook, use it day to day, and move it to the internal storage.

> **Status: experimental.** The boot chain, the image and the installer are written and tested off-device, but have not yet booted on a Chromebook, and the package repository is not published yet ([building](../docs/building.md)). Use a card you can wipe, and keep a ChromeOS recovery USB at hand.

## Supported Chromebooks

| Board | Chromebooks | Profile |
| --- | --- | --- |
| Hayato | ASUS Chromebook Flip CM3 / Detachable CM3200 (MediaTek MT8192) | `google-asurada` |
| Spherion | Acer Chromebook 514 (MediaTek MT8192) | `google-asurada` |

The Hayato is the board the port is being tested on. More boards come from postmarketOS; adding one is in [0002](../specs/0002-devices-and-kernels.md#adding-a-board).

## Before you start

1. **Developer mode.** This erases everything stored on the Chromebook. Enter recovery (Esc + Refresh + Power; on a detachable, Power + Volume Up + Volume Down), then press Ctrl+D and confirm. ChromeOS takes a few minutes to switch.
2. **Allow booting from a card.** In ChromeOS, open a shell (Ctrl+Alt+F2, log in as `chronos`) and run:

   ```bash
   sudo crossystem dev_boot_usb=1 dev_boot_signed_only=0
   ```

3. **A card with the image.** Download (or [build](../docs/building.md)) `omarchy-google-asurada-<date>.img.xz`, check it and write it:

   ```bash
   sha256sum -c omarchy-google-asurada-<date>.img.xz.sha256
   xz -dc omarchy-google-asurada-<date>.img.xz | sudo dd of=/dev/<card> bs=4M conv=fsync
   ```

   The image is 8 GiB, and on a larger card the space after it stays unused for now ([roadmap](../docs/roadmap.md#known-limitations)).

## First boot

Insert the card and power on. At the developer-mode screen, choose **external disk** (on older firmware, press Ctrl+U). Then:

1. Omarchy sets up the hardware for this board. This takes a moment, once.
2. Omarchy's owner wizard appears: keyboard layout, your account, your password.
3. The desktop starts.

During that first boot the kernel is written again for this exact machine. The next reboot tries the new copy once; if it does not start, the Chromebook falls back to the copy it booted from (see [Updates](#updates)).

## The keyboard

A Chromebook has no function row: the top row is Back, Refresh, Fullscreen, brightness and volume, and it stays that way.

| Keys | Does |
| --- | --- |
| Search + top row | F1-F10 |
| Ctrl + Alt + top row | switch to a text console (Ctrl+Alt+F1-F10) |
| Alt + Backspace | Delete |
| Lock key | suspend; the session locks while asleep |
| Search | Super, for every Omarchy shortcut |

Omarchy's keybindings menu shows the brightness and volume shortcuts on the keys they are printed on.

## The lite profile

Chromebook images come with the lite profile, which keeps the Omarchy desktop but leaves out what costs memory at an idle desktop:

- the shell's dock and its agents widget are off;
- window animations are off;
- **PCManFM** is the file manager (Super+Shift+F) instead of Nautilus;
- Chinese, Japanese and Korean input methods are installed when you ask for one (`omarchy setup input mozc`, `hangul`, `pinyin`, `chewing` or `cangjie5`); compose (Shift+CapsLock) works without them;
- removable drives are mounted when you open them in PCManFM, not as soon as they are plugged in;
- printing and network discovery start the first time something uses them;
- the crash watcher is off.

Each can be undone on its own: the [omarchy-lite README](../packages/omarchy-lite/README.md) says how. `omarchy-lite status` shows what is applied.

## Updates

`omarchy update` updates everything, the kernel included. A Chromebook boots a kernel copied into a special partition, so after a kernel update the new kernel is written into the partition that is **not** running, to be tried once at the next boot:

- If it starts, it is marked good and stays.
- If it does not (a black screen, a hang), hold Power to turn the Chromebook off and turn it on again: it starts the previous kernel by itself. Report the failure; `omarchy-chromebook-boot status` shows what happened.

```bash
omarchy-chromebook-boot status          # the kernel partitions, which runs, which boots next
omarchy-chromebook-boot verify          # is the next boot up to date?
sudo omarchy-chromebook-boot write      # write it again now
```

## Moving to the internal storage

Once Omarchy works from the card, copy it onto the Chromebook's internal storage. **This erases ChromeOS and everything else on it**; getting ChromeOS back takes a recovery USB.

```bash
sudo omarchy-chromebook-boot install-internal --disk /dev/mmcblk0
```

It shows the disk, asks you to type its name, lays it out, copies your system (your account and files included), and writes the kernel to it. Shut down, remove the card, and power on: the Chromebook starts from its internal storage. The card still works and can be wiped or kept as a spare.

## If something goes wrong

- **No "external disk" choice:** `dev_boot_usb` is not set (Before you start, step 2), or the card is not written.
- **It falls back to the old kernel after an update:** run `omarchy-chromebook-boot status` and report it, with `journalctl -b -1` from the failed boot if the machine got that far.
- **Back to ChromeOS:** boot a ChromeOS recovery USB (Esc + Refresh + Power, or Power + Volume Up + Volume Down on a detachable).
