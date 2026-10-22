# 0006: Package repository

Status: Draft (needs a signing key and a first build)
Related: [`book/tools/build-packages`](../tools/build-packages), [`.github/workflows/book-packages.yml`](../../.github/workflows/book-packages.yml), [`default/pacman/aarch64-chromebook/`](../../default/pacman/aarch64-chromebook/), [0001](0001-platform-registration.md), [0007](0007-upstream-sync.md)

## Problem

A Chromebook running Omarchy installs and updates from pacman repositories. Arch Linux ARM and `pkgs.omarchy.org` carry almost everything, but not: the board kernels, `depthcharge-tools`, the two platform packages, and (until [0001](0001-platform-registration.md) is merged upstream) an Omarchy runtime that knows the `aarch64-chromebook` platform. Those need a repository of their own that updates as reliably as upstream's.

## Shape

One pacman repository, `[omarchy-chromebook]`, published as the assets of a GitHub release (`chromebook-edge-aarch64`) of this repository, the way Asahi ALARM publishes its own. `book/tools/build-packages` builds it on Arch Linux ARM; a GitHub Actions workflow runs it on a free arm64 runner when asked, signs the packages and the database, and publishes. The Chromebook pacman template lists it first, so its builds win over the same names in `[omarchy]` and Arch Linux ARM.

| Package | From | Version |
| --- | --- | --- |
| `linux-book-<flavor>` (+ `-headers`) | `book/kernels/<flavor>/` | the kernel's, e.g. 7.2.7 |
| `omarchy-chromebook-boot`, `omarchy-chromebook` | `book/packages/` | their `version` files |
| `depthcharge-tools` | `book/recipes/` | 0.6.2 |
| `omarchy-dev`, `omarchy-settings-dev` | omacom/omarchy-pkgs' recipes (pinned in `build-packages`), built from this checkout | `4.0.0.r<commits>.g<hash>`, upstream's scheme, so this fork's builds sort above the upstream build they derive from |

## Rejected approaches

- **Building on the Chromebook.** A kernel build there takes hours and competes with the desktop for 4 GB; the result is not reproducible by anyone else.
- **Cross-compiling on x86.** The kernel would cross-compile, but `makepkg` packages and `pacstrap` want a native Arch Linux ARM; GitHub's arm64 runners make that free for a public repository.
- **Our own server.** A release's assets are a static file server pacman reads fine, with nothing to run. Asahi ALARM does the same.
- **Unsigned packages.** `SigLevel = Required DatabaseOptional` is Omarchy's default; the Chromebook repository meets it rather than weakening it.
- **Vendoring the runtime recipes** (omarchybook vendored `omarchy-dev`). They change with every upstream release; fetching them at a pinned commit keeps them upstream's.

## Requirements

- **R6.1** `build-packages` builds every package above on Arch Linux ARM without writing to the repository tree, and produces `omarchy-chromebook.db`. *Check:* a run in the workflow.
- **R6.2** Packages and database are signed when `BOOK_SIGNING_KEY` is set, and the publish job only runs from `quattro`, by hand. *Check:* the workflow.
- **R6.3** The published release holds the packages the database names, and no others. *Check:* the publish job's last step.
- **R6.4** Every push touching `book/` runs the package tests, `check-devices` and the upstream tests of the registration. *Check:* the workflow's `test` job.
- **R6.5** The repository's public key reaches machines as a package (`omarchy-book-keyring`), so a rotation is an update. *Check:* to do.

## Setting it up (maintainer, once)

1. Make a signing key for the repository: `gpg --quick-gen-key "Omarchy Book <you@example.com>" ed25519 sign never`.
2. Add its armored private key as the repository secret `BOOK_SIGNING_KEY` (Settings → Secrets and variables → Actions).
   If it has a passphrase, add that as `BOOK_SIGNING_PASSPHRASE` too.
3. Commit its public half as `book/keys/omarchy-book.gpg`, so the image builder trusts it.
4. Run the workflow from the Actions tab with **build** and **publish** checked.

## Tasks

- [x] `build-packages`
- [x] The workflow: test on push, build and publish on request
- [ ] The signing key (maintainer)
- [ ] First build and publish
- [ ] `omarchy-book-keyring`, and `omarchy-keyring`'s trust of it in the image
- [ ] Build the image in the workflow too (a privileged container for loop devices), and attach it to a release

## Changelog

- 2026-10-22: created.
