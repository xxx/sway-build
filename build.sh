#!/bin/sh
# Build the image, assemble the relocatable bundle into ./out, then verify it on
# the host. Re-runnable; ./out is recreated each run.
set -eu
cd "$(dirname "$0")"
IMAGE=sway-build
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/glass/sway"

# `./build.sh install` copies an already-built bundle to the glass discovery
# location (~/.local/share/glass/sway), so glass finds sway with zero config.
# Override DEST to install elsewhere.
if [ "${1:-}" = "install" ]; then
    [ -d out ] || { echo "no ./out — run ./build.sh first"; exit 1; }
    rm -rf "$DEST"
    mkdir -p "$(dirname "$DEST")"
    cp -a out "$DEST"
    echo "installed bundle to $DEST (glass auto-discovers it; out/bin/sway also runs directly)"
    exit 0
fi

echo "==> docker build"
docker build -t "$IMAGE" .

echo "==> assemble bundle into ./out"
rm -rf out
mkdir -p out
docker run --rm -v "$PWD/out:/out" "$IMAGE" /usr/local/bin/assemble-bundle.sh

echo "==> bundle contents"
ls -R out | head -40

echo "==> verify on host"
./verify.sh

echo "==> OK: bundle at $PWD/out (run out/bin/sway)"
