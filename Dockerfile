# syntax=docker/dockerfile:1
FROM ubuntu@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential meson ninja-build cmake pkg-config git ca-certificates \
      wget python3 libxml2-dev bison \
      libwayland-dev libxkbcommon-dev libpixman-1-dev libdrm-dev libgbm-dev \
      libegl-dev libgles-dev \
      libinput-dev libseat-dev libudev-dev hwdata \
      libpango1.0-dev libcairo2-dev libgdk-pixbuf-2.0-dev \
      libjson-c-dev libpcre2-dev scdoc \
      libxcb1-dev libxcb-composite0-dev libxcb-icccm4-dev libxcb-render0-dev \
      libxcb-res0-dev libxcb-ewmh-dev xwayland \
    && rm -rf /var/lib/apt/lists/*

ENV PREFIX=/usr/local
ENV PKG_CONFIG_PATH=$PREFIX/lib/x86_64-linux-gnu/pkgconfig:$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig
ENV LD_LIBRARY_PATH=$PREFIX/lib/x86_64-linux-gnu:$PREFIX/lib

# --- from-source deps newer than 24.04 (pinned). Bump tags if meson demands. ---
# wayland (libwayland) — 24.04 has 1.22; wlroots 0.20 needs newer.
RUN git clone --depth 1 --branch 1.24.0 https://gitlab.freedesktop.org/wayland/wayland.git /src/wayland && \
    meson setup /src/wayland/build /src/wayland --prefix=$PREFIX -Dtests=false -Ddocumentation=false && \
    ninja -C /src/wayland/build install

# wayland-protocols — must include staging/ext-image-copy-capture + ext-image-capture-source.
RUN git clone --depth 1 --branch 1.47 https://gitlab.freedesktop.org/wayland/wayland-protocols.git /src/wp && \
    meson setup /src/wp/build /src/wp --prefix=$PREFIX && \
    ninja -C /src/wp/build install

# libdrm — 24.04 has 2.4.120; wlroots 0.20 needs newer.
RUN git clone --depth 1 --branch libdrm-2.4.132 https://gitlab.freedesktop.org/mesa/drm.git /src/drm && \
    meson setup /src/drm/build /src/drm --prefix=$PREFIX -Dtests=false && \
    ninja -C /src/drm/build install

# libdisplay-info — 24.04 has 0.1.1; wlroots 0.20 needs >=0.2.
RUN git clone --depth 1 --branch 0.2.0 https://gitlab.freedesktop.org/emersion/libdisplay-info.git /src/ldi && \
    meson setup /src/ldi/build /src/ldi --prefix=$PREFIX && \
    ninja -C /src/ldi/build install

# libxkbcommon — 24.04 has 1.6.0; wlroots 0.20 needs >=1.8.
RUN git clone --depth 1 --branch xkbcommon-1.8.0 https://github.com/xkbcommon/libxkbcommon.git /src/xkb && \
    meson setup /src/xkb/build /src/xkb --prefix=$PREFIX \
      -Denable-x11=false -Denable-wayland=false -Denable-docs=false && \
    ninja -C /src/xkb/build install

# pixman — 24.04 has 0.42.2; wlroots 0.20 needs >=0.43.
RUN git clone --depth 1 --branch pixman-0.46.0 https://gitlab.freedesktop.org/pixman/pixman.git /src/pixman && \
    meson setup /src/pixman/build /src/pixman --prefix=$PREFIX -Dtests=disabled -Ddemos=disabled && \
    ninja -C /src/pixman/build install

# libinput — 24.04 has 1.25; sway 1.12 needs >=1.26 (build before wlroots so both agree).
RUN apt-get update && apt-get install -y --no-install-recommends libevdev-dev && rm -rf /var/lib/apt/lists/* && \
    git clone --depth 1 --branch 1.27.0 https://gitlab.freedesktop.org/libinput/libinput.git /src/libinput && \
    meson setup /src/libinput/build /src/libinput --prefix=$PREFIX \
      -Dtests=false -Ddocumentation=false -Dlibwacom=false -Ddebug-gui=false && \
    ninja -C /src/libinput/build install

# --- wlroots 0.20 ---
RUN git clone --depth 1 --branch 0.20.0 https://gitlab.freedesktop.org/wlroots/wlroots.git /src/wlroots && \
    meson setup /src/wlroots/build /src/wlroots --prefix=$PREFIX \
      -Drenderers=gles2 -Dbackends=drm,libinput -Dexamples=false && \
    ninja -C /src/wlroots/build install

# --- sway 1.12 ---
RUN git clone --depth 1 --branch 1.12 https://github.com/swaywm/sway.git /src/sway && \
    meson setup /src/sway/build /src/sway --prefix=$PREFIX \
      -Dwerror=false -Dman-pages=disabled -Dswaybar=false && \
    ninja -C /src/sway/build install && ldconfig

COPY assemble-bundle.sh /usr/local/bin/assemble-bundle.sh
RUN chmod +x /usr/local/bin/assemble-bundle.sh
