# Building

How to go from this repository to a card that boots a Chromebook: packages first, then the image. The design behind each step is in [0006](../specs/0006-package-repository.md) and [0004](../specs/0004-image-and-install.md).

## What you need

- **An Arch Linux ARM environment on aarch64**, with root and loop devices for the image: an ARM machine, a Chromebook already running this port, or a privileged container of the image the CI uses (`ghcr.io/menci/archlinuxarm@sha256:3e1074c4…`, pinned in [`.github/workflows/book-packages.yml`](../../.github/workflows/book-packages.yml)). x86 is not supported for either step.
- For packages: `base-devel`, `git`, and a user with `sudo` (makepkg refuses root).
- For the image: `arch-install-scripts`, `btrfs-progs`, `parted`, `vboot-utils`, `util-linux`, `xz`.
- A microSD card or USB stick of at least 8 GiB.

## 1. Packages

### On GitHub (the normal way)

Once, as the repository's maintainer:

1. Make a signing key: `gpg --quick-gen-key "Omarchy Book <you@example.com>" ed25519 sign never`.
2. Add its armored private key (`gpg --armor --export-secret-keys <id>`) as the repository secret **`BOOK_SIGNING_KEY`** (Settings → Secrets and variables → Actions).
   If the key has a passphrase, add it as a second secret, **`BOOK_SIGNING_PASSPHRASE`**: nobody can type it in CI, so the workflow hands it to gpg from a file. The workflow test-signs right after importing the key and stops with an explanation if signing would fail.
3. Commit its public half as `book/keys/omarchy-book.gpg` (`gpg --armor --export <id>`), so the image builder trusts it.

Then, each time: Actions → **Book packages** → Run workflow on `quattro`, with **build** checked, and **publish** to update the `chromebook-edge-aarch64` release the Chromebook pacman template reads. GitHub offers a manually run workflow only once it is on the default branch, and the publish job runs only from `quattro`, so this works after the `chromebook-platform` branch is merged. The kernel dominates the build time (not measured yet; expect an hour or more). Without the secret the packages are built unsigned, which is fine for testing (download the artifact) but not for publishing.

### Locally

```bash
book/tools/build-packages --out ~/omarchy-repo            # unsigned
book/tools/build-packages --out ~/omarchy-repo --sign <id>
book/tools/build-packages --out ~/omarchy-repo --skip-kernels   # quick, for the scripts' packages
```

It builds `depthcharge-tools`, the three `book/packages`, every kernel in `book/kernels`, and Omarchy's runtime from this checkout, and writes `omarchy-chromebook.db` beside them. The repository tree is not written to.

## 2. The image

```bash
sudo book/tools/build-image --device google-asurada --output ~/images
sudo book/tools/build-image --device google-asurada --repo ~/omarchy-repo     # with local packages
sudo book/tools/build-image --device google-asurada --profile full            # without the lite profile
```

Options: `--size` (default `8G`; the root partition fills it), `--profile lite|full` (default `lite`), `--repo DIR` (a local repository from step 1, trusted for this build only; the image itself still updates from the published one), `--keep-mounted` (leave the image mounted to inspect it).

It writes `omarchy-<device>-<date>.img.xz` and its `.sha256`. The build log prints a warning if the lite profile leaves out a package Omarchy's default set no longer names: update `book/packages/omarchy-lite/share/subtract.packages` then.

## 3. A card

```bash
sha256sum -c omarchy-google-asurada-<date>.img.xz.sha256
xz -dc omarchy-google-asurada-<date>.img.xz | sudo dd of=/dev/<card> bs=4M conv=fsync
```

Then follow the [install guide](../manual/install.md).

## After a change

| You changed | Rebuild |
| --- | --- |
| a board profile (`book/devices/`) | `omarchy-chromebook-boot` (it ships the profiles), then an image |
| a kernel (`book/kernels/`) | that kernel; installed machines pick it up through `omarchy update` |
| a platform package or the lite profile | that package |
| anything in the Omarchy runtime (outside `book/`) | `omarchy-dev` and `omarchy-settings-dev` (the workflow always rebuilds them) |
| `book/tools/build-image` | only the image |
