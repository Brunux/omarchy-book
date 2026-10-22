# Provenance: google-asurada

Google's MT8192 Chromebooks built on the Asurada baseboard: the **Hayato** (ASUS Chromebook Flip CM3 / Detachable CM3200, the board this port is tested on) and the **Spherion** (Acer Chromebook 514).

## Source

pmaports `device/community/device-google-asurada/`, branch `main`, compared on 2026-10-22 at commit `63713ff744122484552736cb28e6980f6ea0d190`. `deviceinfo`, `modules-initfs` and `APKBUILD.reference` are pmaports' byte for byte; they reached this repository through [LazyOS](https://github.com/Brunux/LazyOS), which boots them on the Hayato.

## Changes from pmaports

- `kernel-cmdline.conf` adds `transparent_hugepage=madvise`: with `always`, a 4 GB machine swapping to zram faults whole 2 MB pages where 4 KB ones would do (LazyOS `docs/optimization.md` item 12).

## Written for this port

- `compatible`: the boards' device-tree names, from mainline's `mt8192-asurada-hayato-r1.dts` (`google,hayato`) and `mt8192-asurada-spherion-r0.dts` (`google,spherion`). They are what `omarchy-chromebook-boot` matches against `/proc/device-tree/compatible` to pick this profile.
- `kernel`: pmaports names the kernel in the APKBUILD's `depends` (`linux-postmarketos-mediatek-mt81`); this file names the flavor directly.
- `packages`: the APKBUILD's firmware `depends`, in Arch Linux ARM's names. `alsa-ucm-conf` and `depthcharge-tools` come with the platform packages instead, since every Chromebook needs them.
