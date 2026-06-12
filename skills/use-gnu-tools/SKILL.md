---
name: use-gnu-tools
description: "GLOBAL mandatory preference: Always use Homebrew-installed GNU/F-OSS tools over macOS/BSD/Darwin built-ins. This applies universally to every task, with zero exceptions. macOS ships ancient, broken BSD tools under /usr/bin — NEVER use them. Always prefer the modern GNU versions installed via Homebrew under /opt/homebrew/. This is a strict, non-negotiable user preference."
---

# Use Homebrew GNU Tools — Always

This is a **non-negotiable, universal preference** that applies to every scenario.

macOS ships ancient BSD variants of common CLI tools under `/usr/bin`. These have incompatible flags, missing features, and broken behavior compared to modern GNU versions. **NEVER use them.**

Always use the Homebrew-installed GNU tools from `/opt/homebrew/`.

## gnubin Directories in PATH

These directories provide unprefixed GNU tool names and take precedence:

```text
/opt/homebrew/opt/coreutils/libexec/gnubin
/opt/homebrew/opt/gnu-sed/libexec/gnubin
/opt/homebrew/opt/gnu-tar/libexec/gnubin
/opt/homebrew/opt/grep/libexec/gnubin
/opt/homebrew/opt/gawk/libexec/gnubin
/opt/homebrew/opt/findutils/libexec/gnubin
/opt/homebrew/opt/moreutils/libexec/gnubin
/opt/homebrew/libexec/gnubin
```

## Rules

1. **NEVER** invoke any tool from `/usr/bin/` when a Homebrew equivalent exists.
2. When in doubt, use the `g`-prefixed GNU name to be explicit and safe:

| macOS BSD (NEVER USE)   | GNU/Homebrew (ALWAYS USE) |
|-------------------------|---------------------------|
| `/usr/bin/sed`          | `gsed`                    |
| `/usr/bin/awk`          | `gawk`                    |
| `/usr/bin/tar`          | `gtar`                    |
| `/usr/bin/grep`         | `ggrep`                   |
| `/usr/bin/find`         | `gfind` (but prefer `fd`) |
| `/usr/bin/xargs`        | `gxargs`                  |
| `/usr/bin/sort`         | `gsort`                   |
| `/usr/bin/head`         | `ghead`                   |
| `/usr/bin/tail`         | `gtail`                   |
| `/usr/bin/cut`          | `gcut`                    |
| `/usr/bin/wc`           | `gwc`                     |
| `/usr/bin/stat`         | `gstat`                   |
| `/usr/bin/date`         | `gdate`                   |
| `/usr/bin/ls`           | `gls`                     |
| `/usr/bin/readlink`     | `greadlink`               |
| `/usr/bin/realpath`     | `grealpath`               |
| `/usr/bin/mktemp`       | `gmktemp`                 |
| `/usr/bin/install`      | `ginstall`                |
| `/usr/bin/du`           | `gdu`                     |
| `/usr/bin/df`           | `gdf`                     |
| `/usr/bin/uniq`         | `guniq`                   |
| `/usr/bin/tr`           | `gtr`                     |
| `/usr/bin/basename`     | `gbasename`               |
| `/usr/bin/dirname`      | `gdirname`                |

3. **`sed` is especially critical** — always use `gsed`. The BSD `sed` under `/usr/bin/sed` has fundamentally broken in-place editing, different regex syntax, and missing features. There is **zero tolerance** for using `/usr/bin/sed`.

4. For tools that don't have a `g`-prefix (e.g., Homebrew `grep` in gnubin), the gnubin PATH entries ensure the GNU version is resolved first — but when writing scripts, prefer the explicit `g`-prefixed name for clarity.

5. This preference extends to **all contexts**: shell commands, scripts, code generation, suggestions, and explanations.
