#!/bin/sh
# Runs INSIDE the build image. Copies sway/swaymsg + their non-system shared-lib
# closure into /out, and writes LD_LIBRARY_PATH wrappers. Excludes the glibc
# loader and the Mesa/GL/driver/libdrm stack so those resolve from the HOST
# (where the GPU/llvmpipe live), which is what lets GL apps work.
set -eu
OUT=/out
mkdir -p "$OUT/bin" "$OUT/lib"

# Host-ABI libs to EXCLUDE (resolved from the host at runtime).
EXCLUDE='^(ld-linux|libc\.so|libm\.so|libmvec|libpthread|libdl|librt|libresolv|libnss|libGL|libEGL|libGLES|libOpenGL|libGLdispatch|libGLX|libglapi|libgbm|libdrm)'

copy_deps() {
    # ldd is transitive; take the resolved "=> /path" entries only.
    ldd "$1" | awk '/=> \// {print $3}' | while read -r so; do
        [ -e "$so" ] || continue
        base=$(basename "$so")
        if echo "$base" | grep -Eq "$EXCLUDE"; then continue; fi
        cp -uL "$so" "$OUT/lib/"
    done
}

for b in sway swaymsg; do
    real=$(command -v "$b") || { echo "FATAL: $b not on PATH in image" >&2; exit 1; }
    cp -L "$real" "$OUT/bin/$b.real"
    copy_deps "$real"
    cat > "$OUT/bin/$b" <<EOF
#!/bin/sh
here=\$(cd "\$(dirname "\$0")" && pwd)
export LD_LIBRARY_PATH="\$here/../lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "\$here/$b.real" "\$@"
EOF
    chmod +x "$OUT/bin/$b"
done

echo "assembled: $(ls "$OUT/bin") ; $(ls "$OUT/lib" | wc -l) libs"
