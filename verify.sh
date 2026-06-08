#!/bin/sh
# Run the assembled bundle's sway headless on the HOST and assert it advertises
# the wlroots-class protocols a modern compositor should (wlr globals + the
# ext-image-copy-capture stack). The dmabuf/EGL path is checked too but only
# warned on: it depends on a GPU/render node and is absent under pure software
# rendering (CI). Self-contained: needs only `wayland-info` (apt install
# wayland-utils); skipped with a warning if absent.
set -eu
cd "$(dirname "$0")"
SWAY="$PWD/out/bin/sway"
[ -x "$SWAY" ] || { echo "FAIL: $SWAY missing (run ./build.sh first)"; exit 1; }
if ! command -v wayland-info >/dev/null 2>&1; then
    echo "SKIP verify: wayland-info not installed (apt install wayland-utils)"
    exit 0
fi

RT=$(mktemp -d /tmp/sway-verify.XXXXXX); chmod 700 "$RT"
CFG="$RT/sway.cfg"
cat > "$CFG" <<EOF
output HEADLESS-1 resolution 1280x720
default_border none
EOF

env -u WAYLAND_DISPLAY -u DISPLAY -u WAYLAND_SOCKET \
    XDG_RUNTIME_DIR="$RT" WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER_ALLOW_SOFTWARE=1 \
    "$SWAY" --unsupported-gpu -c "$CFG" >"$RT/sway.log" 2>&1 &
SWAY_PID=$!
trap 'kill "$SWAY_PID" 2>/dev/null; sleep 0.3; kill -9 "$SWAY_PID" 2>/dev/null; rm -rf "$RT"' EXIT

SOCK=""
i=0; while [ $i -lt 60 ]; do
    SOCK=$(ls "$RT" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1 || true)
    [ -n "$SOCK" ] && break
    sleep 0.2; i=$((i+1))
done
[ -n "$SOCK" ] || { echo "FAIL: sway created no wayland socket"; sed -n '1,30p' "$RT/sway.log"; exit 1; }
sleep 2

INFO=$(env -u DISPLAY XDG_RUNTIME_DIR="$RT" WAYLAND_DISPLAY="$SOCK" wayland-info 2>/dev/null || true)

# Required globals — the wlr/ext protocols glass drives. These do not depend on a GPU.
fail=0
for g in zwlr_screencopy_manager_v1 zwlr_virtual_pointer_manager_v1 \
         zwp_virtual_keyboard_manager_v1 zwlr_foreign_toplevel_manager_v1 \
         ext_image_copy_capture_manager_v1 ext_foreign_toplevel_image_capture_source_manager_v1; do
    if echo "$INFO" | grep -q "$g"; then
        echo "  ok   $g"
    else
        echo "  MISS $g"; fail=1
    fi
done

# Optional: dmabuf/EGL path. Present with a GPU/render node, absent under pure
# software rendering (llvmpipe, no /dev/dri) as on a GPU-less CI runner. glass
# captures to shm, so this is informational — warn, don't fail.
for g in zwp_linux_dmabuf_v1; do
    if echo "$INFO" | grep -q "$g"; then
        echo "  ok   $g (optional)"
    else
        echo "  warn $g absent (no GPU/render node — software rendering)"
    fi
done

[ "$fail" -eq 0 ] || { echo "FAIL: bundle missing required globals"; exit 1; }
echo "VERIFY OK: bundle advertises the required wlr/ext globals"
