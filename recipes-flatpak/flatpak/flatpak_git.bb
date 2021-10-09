DESCRIPTION = "Versioned Application/Runtime Respository."
HOMEPAGE = "http://flatpak.org"
LICENSE = "LGPLv2.1"
LIC_FILES_CHKSUM = "file://COPYING;md5=4fbd65380cdd255951079008b364516c"

SRC_URI = " \
    gitsm://git@github.com/flatpak/flatpak;protocol=https;branch=flatpak-1.12.x \
"

SRCREV = "afb3575d3113a8491af25af3bbc7bcf1cb5b9b33"

PV = "1.12.1+git${SRCPV}"
S = "${WORKDIR}/git"

inherit autotools pkgconfig gettext systemd gobject-introspection gtk-doc manpages

DEPENDS = " \
    glib-2.0 json-glib libsoup-2.4 libarchive elfutils fuse \
    ostree libassuan libgpg-error systemd \
    gpgme appstream-glib python3-pyparsing-native bison-native \
    libseccomp polkit \
"

DEPENDS_class-native = " \
    glib-2.0-native libsoup-2.4-native json-glib-native libarchive-native \
    elfutils-native fuse-native ostree-native \
    libassuan-native libgpg-error-native \
    gpgme-native appstream-glib-native python3-pyparsing-native bison-native \
"

RDEPENDS_${PN}_class-target = " \
    ca-certificates \
"

AUTO_LIBNAME_PKGS = ""

# package configuration
PACKAGECONFIG ?= ""

PACKAGECONFIG[seccomp] = "--enable-seccomp,--disable-seccomp,seccomp"
PACKAGECONFIG[x11] = "--enable-xauth,--disable-xauth,x11"
PACKAGECONFIG[system-helper] = "--enable-system-helper,--disable-system-helper,polkit"

EXTRA_OECONF += " \
    --disable-docbook-docs \
    --disable-gtk-doc-html \
    --disable-documentation \
    --with-systemdsystemunitdir=${systemd_unitdir}/system \
"

EXTRA_OECONF_class-target += " \
    --disable-docbook-docs \
    --disable-gtk-doc-html \
    --disable-documentation \
    --with-systemdsystemunitdir=${systemd_unitdir}/system \
    --disable-selinux-module \
"

# package content
PACKAGES =+ " \
    ${PN}-build \
    ${PN}-bash-completion \
    ${PN}-gdm \
"

FILES_${PN} += " \
    ${systemd_unitdir} \
    ${libdir}/systemd/user/*.service \
    ${libdir}/systemd/user/dbus.service.d/*.conf \
    ${libdir}/systemd/system-environment-generators/60-flatpak-system-only \
    ${libdir}/systemd/user-environment-generators/60-flatpak \
    ${libdir}/girepository-1.0 \
    ${datadir}/gir-1.0 \
    ${datadir}/dbus-1/services/*.service \
    ${datadir}/dbus-1/interfaces/*.xml \
"

FILES_${PN}-build = "${bindir}/flatpak-builder"

FILES_${PN}-bash-completion = " \
    ${sysconfdir}/profile.d/flatpak.sh \
    ${datadir}/bash-completion/completions/flatpak \
    ${datadir}/zsh/site-functions/_flatpak \
    ${datadir}/fish/vendor_completions.d/flatpak.fish \
"

FILES_${PN}-gdm = " \
    ${datadir}/gdm/env.d/flatpak.env \
"

SYSROOT_DIR = "${STAGING_DIR_TARGET}"
SYSROOT_DIR_class-native = "${STAGING_DIR_NATIVE}"
do_configure[vardeps] += "SYSROOT_DIR"

do_configure_prepend() {
    # this reflects what autogen.sh does, but the OE wrappers for autoreconf
    # allow it to work without the other gyrations which exist there
    sed -e 's,$(libglnx_srcpath),subprojects/libglnx,g' < ${S}/subprojects/libglnx/Makefile-libglnx.am >${S}/subprojects/libglnx/Makefile-libglnx.am.inc
    sed -e 's,$(bwrap_srcpath),subprojects/bubblewrap,g' < ${S}/subprojects/bubblewrap/Makefile-bwrap.am >${S}/subprojects/bubblewrap/Makefile-bwrap.am.inc
}

BBCLASSEXTEND = "native"
