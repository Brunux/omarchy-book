# 0007: Upstream sync

Status: Accepted
Related: [`book/AGENTS.md`](../AGENTS.md), [0001](0001-platform-registration.md)

## Problem

This fork is only worth having if it stays Omarchy: same commands, same fixes, same releases a day later. Every upstream change has to reach it, and nothing about the port may make that merge expensive.

## Shape

`quattro` here is upstream's `quattro` plus the registration of [0001](0001-platform-registration.md) and the `book/` directory. Upstream is merged in, never rebased onto (published history stays published), and each merge is checked the same way.

## Requirements

- **R7.1** Outside `book/` and `.github/workflows/book-packages.yml`, the fork differs from upstream only in the files [0001](0001-platform-registration.md) lists. *Check:* the diff stat below.
- **R7.2** After a merge, upstream's own tests touched by the registration pass, and so do the packages' tests and `check-devices`. *Check:* the commands below.

## A sync

```bash
git remote add upstream https://github.com/omacom/omarchy.git   # once
git fetch upstream quattro
git merge upstream/quattro

# Only 0001's files may show here.
git diff --stat upstream/quattro -- . ':!book' ':!.github/workflows/book-packages.yml'

# Upstream tests the registration lives in (as an unprivileged user: the
# platform fixtures are ignored for root).
for t in hw-platform image-target-platform lifecycle-dispatch pacman-templates platform-packages platform-setup; do
  bash test/shell.d/$t-test.sh >/tmp/$t.log 2>&1 || echo "FAIL $t (see /tmp/$t.log)"
done

book/packages/omarchy-chromebook-boot/test/all
book/packages/omarchy-chromebook/test/all
book/packages/omarchy-lite/test/all
book/tools/check-devices
```

### When upstream changes a seam

- **A new platform** upstream (a new `aarch64-<family>`): its additions land next to ours in the same lists; resolve by keeping both.
- **A new lifecycle operation**: read its contract in `docs/lifecycle-dispatch.md` and decide in [0003](0003-boot-package.md) whether Chromebooks need it required, optional, or implemented.
- **The Limine command-line files** (`/etc/limine-entry-tool.d/`) move or change format: `lib/cmdline.sh` follows, since a Chromebook's command line is built from them.
- **The image manifest or `--defer-provisioning`** changes: `book/tools/build-image` follows.
- **The default package set** changes: nothing to do; the image builder composes it at build time.

### When the registration is merged upstream

Drop the fork's copy in the merge (take upstream's side), keep only the repository line in `default/pacman/aarch64-chromebook/`, and stop building the runtime in [0006](0006-package-repository.md).

## Changelog

- 2026-10-22: created.
