# Portable sway bundle

A reproducible Docker build of a **relocatable `sway` ≥ 1.12 / wlroots ≥ 0.20**
that runs on older distros whose packages are too old. Ubuntu 24.04's `apt`, for
example, ships sway 1.9 / wlroots 0.17 — missing recent protocols like
`ext-image-copy-capture`.

It was built to give the **glass** project a modern headless sway with zero
system-wide install, but the bundle is a plain relocatable directory that runs
anywhere. Once your distro ships sway ≥ 1.12 you won't need this.

## Build

```bash
./build.sh
```

Output: `out/` (gitignored) — run `out/bin/sway`. The `out/bin/sway` wrapper sets
`LD_LIBRARY_PATH` to the bundled libs; Mesa/GL/`libdrm`/glibc resolve from the host.

## Host runtime requirement

Only basic Mesa (present on any graphical Linux host), so GL apps work with the
host GPU or llvmpipe:

```bash
sudo apt-get install -y libegl1 libgl1-mesa-dri
```

## Install

```bash
./build.sh            # build the bundle into ./out
./build.sh install    # copy it to ~/.local/share/glass/sway
```

`install` copies the bundle to `~/.local/share/glass/sway` (override with
`XDG_DATA_HOME`), which is where glass auto-discovers sway — no env var needed.
glass checks `PATH` first (if `sway --version` ≥ 1.12), then that directory, then a
`sway/` dir next to its binary. You can also just run `out/bin/sway` directly.

## Verify

```bash
./verify.sh           # needs wayland-info (apt install wayland-utils)
```

Runs the bundled sway headless and asserts it advertises the expected wlroots-class
globals (screencopy, virtual pointer/keyboard, foreign-toplevel, the
ext-image-copy-capture stack, dmabuf). `build.sh` runs this automatically.

## Pinned versions

All pinned in the `Dockerfile` (the single source of truth):

- base image: `ubuntu@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54` (`ubuntu:24.04`)
- sway: `1.12`  ·  wlroots: `0.20.0`
- from-source deps (newer than 24.04 ships): wayland `1.24.0`, wayland-protocols
  `1.47`, libdrm `2.4.132`, libdisplay-info `0.2.0`, libxkbcommon `1.8.0`,
  pixman `0.46.0`, libinput `1.27.0`

## License

MIT — see [LICENSE](LICENSE). sway and wlroots themselves are MIT-licensed
upstream; the bundle links the usual wlroots dependency stack dynamically.
