# Provenance: mediatek-mt81

The kernel postmarketOS builds for MediaTek Chromebooks with MT8183 and later, `linux-postmarketos-mediatek-mt81`, packaged for Arch Linux ARM as `linux-book-mediatek-mt81`.

## Source

- pmaports `device/community/linux-postmarketos-mediatek-mt81/`, branch `main`, compared on 2026-10-22 at commit `63713ff744122484552736cb28e6980f6ea0d190`: `APKBUILD.reference` is that recipe byte for byte (pkgver 7.2.7, pkgrel 0).
- `patches/*.patch` are pmaports' patches byte for byte (their sha512s match the APKBUILD's), and `patches/series` is their order in the APKBUILD's `source=`.
- `config.aarch64` came through [LazyOS](https://github.com/Brunux/LazyOS) (`kernels/mediatek-mt81/config.aarch64` at `0cd4e06`), where it boots the Google Hayato.

## Changes from pmaports' config

Each one was measured or needed on hardware; none is a guess.

| Option | pmaports | Here | Why |
| --- | --- | --- | --- |
| `CONFIG_LRU_GEN`, `CONFIG_LRU_GEN_ENABLED` | off | on | Multi-generational LRU: reclaim on a 4 GB machine under zram (LazyOS `docs/optimization.md` item 1). |
| `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL` | ondemand | schedutil | ondemand pinned both clusters at their top frequency (measured `time_in_state`, item 2). |
| `CONFIG_HZ_1000` | 250 | 1000 | Input and scheduling latency for a desktop (item 3). |
| `CONFIG_PREEMPT_DYNAMIC` | off | on | Lets `preempt=` be chosen on the command line, for A/B testing without a rebuild (item 4). |
| `CONFIG_NETFILTER_XT_MATCH_LIMIT`, `CONFIG_IP6_NF_MATCH_RT`, `CONFIG_IP6_NF_MATCH_HL` | off | m | Omarchy's `ufw` rules use `-m limit`, `-m rt` and `-m hl`; without them ufw fails at boot ([omarchybook](https://github.com/Brunux/omarchybook) `docs/recon.md` §14). |
| `CONFIG_CRYPTO_USER` | off | m | bluez's `modules-load.d/bluez.conf` asks for it (same report). |

## Re-importing

`book/tools/pmaports-import mediatek-mt81` fetches the recipe and patches again and shows how they differ from these. A new kernel version updates `pkgver`, the tarball checksum and the patch series in the `PKGBUILD`; the config is then `make olddefconfig`'d on the new tree and the table above re-applied.
