# vboot developer keys

`depthchargectl build` signs each kernel partition with ChromiumOS' **developer keys**, which every Chromebook in developer mode accepts (`dev_boot_signed_only=0`). Debian ships them in `vboot-kernel-utils`; Arch Linux ARM's `vboot-utils` (which provides `cgpt` and `futility`) does not, so this package carries them and passes them to `depthchargectl` with `--vboot-keyblock`, `--vboot-public-key` and `--vboot-private-key`.

They are public test keys from `chromiumos/platform/vboot_reference` (`tests/devkeys/`), not secrets: they prove nothing about who built a kernel, which is what developer mode means.

| File | sha256 |
| --- | --- |
| `kernel.keyblock` | `4e708c9ec43ac4a5d718474c9431ba6b6da3e64a9dda6afd2853a9e9e3079ffb` |
| `kernel_data_key.vbprivk` | `bc9e707a86e55a93f423e7bcdae4a25fd470b868e53829b91bbe2ccfbc6da27b` |
| `kernel_subkey.vbpubk` | `36b9c5fa6f5d0432b9acbe8e2b7da2e602162a87a425575c6d7ba975a0440708` |

Source: `vboot_reference` revision `10343b821`, the one Arch Linux ARM's `vboot-utils` (`r2729.10343b821`) is built from, by way of [omarchybook](https://github.com/Brunux/omarchybook) (`boot/devkeys/`).
