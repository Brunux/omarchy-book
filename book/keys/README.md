# Package signing keys

Public keys the image builder imports into the build host's pacman keyring, so `pacstrap` can verify what it installs. Only public halves live here.

| File | Key | Signs | Source |
| --- | --- | --- | --- |
| `omarchy.gpg` | `40DF B630 FF42 BCFF B047 046C F013 4EE6 80CA C571`, Omarchy &lt;pkgs@omarchy.org&gt; | `pkgs.omarchy.org` | omacom/omarchy-iso `builder/omarchy.gpg` at `6569208c0bc89c923833b4febfb446ded354e45f` |
| `omarchy-book.gpg` | `D0B1 3C36 7F35 2543 F425 7120 E534 9252 2145 0475` | the Chromebook repository (kernels, platform packages, the Omarchy runtime built from this fork) | [specs/0006](../specs/0006-package-repository.md) |

The installed system gets these from packages instead (`omarchy-keyring`, and `omarchy-book-keyring` once 0006 is done), so a key rotation reaches machines through updates, not through this directory.
