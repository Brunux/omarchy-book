# Package signing keys

Public keys the image builder imports into the build host's pacman keyring, so `pacstrap` can verify what it installs. Only public halves live here.

| File | Key | Signs | Source |
| --- | --- | --- | --- |
| `omarchy.gpg` | `40DF B630 FF42 BCFF B047 046C F013 4EE6 80CA C571`, Omarchy &lt;pkgs@omarchy.org&gt; | `pkgs.omarchy.org` | omacom/omarchy-iso `builder/omarchy.gpg` at `6569208c0bc89c923833b4febfb446ded354e45f` |
| `omarchy-book.gpg` | `D85F FD59 3053 3CB6 6AFF 33BD CD71 B6FD 87FD B33F`, the maintainer's ed25519 signing key | the Chromebook repository (kernels, platform packages, the Omarchy runtime built from this fork) | made by the maintainer for [specs/0006](../specs/0006-package-repository.md); its private half is the `BOOK_SIGNING_KEY` Actions secret |

The installed system gets these from packages instead (`omarchy-keyring`, and `omarchy-book-keyring` once 0006 is done), so a key rotation reaches machines through updates, not through this directory.
