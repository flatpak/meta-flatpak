DESCRIPTION = "Versioned Application/Runtime Respository."
HOMEPAGE = "http://flatpak.org"
LICENSE = "LGPLv2.1"
LIC_FILES_CHKSUM = "file://COPYING;md5=4fbd65380cdd255951079008b364516c"

SRC_URI = " \
    gitsm://git@github.com/flatpak/flatpak;protocol=https \
    file://0001-autogen.sh-fall-back-to-no-gtkdocize-if-it-is-there-.patch \
    file://0001-common-Allow-command-to-include-command-line-options.patch \
    file://0001-lib-Allow-passing-command-line-argument-through-laun.patch \
"

SRCREV = "a5536d0420df8a537ab8327319a431127b0ebed7"

PV = "2016.8+git${SRCPV}"
S = "${WORKDIR}/git"

PACKAGES =+ " \
    ${PN}-build \
    ${PN}-bash-completion \
    ${PN}-gdm \
"

FILES_${PN} += " \
    ${libdir}/systemd/user/*.service \
    ${libdir}/systemd/user/dbus.service.d/*.conf \
    ${libdir}/girepository-1.0 \
    ${datadir}/gir-1.0 \
    ${datadir}/dbus-1/services/*.service \
    ${datadir}/dbus-1/interfaces/*.xml \
"

FILES_${PN}-build = "${bindir}/flatpak-builder"

FILES_${PN}-bash-completion = " \
    ${sysconfdir}/profile.d/flatpak.sh \
    ${datadir}/bash-completion/completions/flatpak \
"

FILES_${PN}-gdm = " \
    ${datadir}/gdm/env.d/flatpak.env \
"

AUTO_LIBNAME_PKGS = ""

# possible package configurations
PACKAGECONFIG ??= ""

do_configure_prepend() {
    cd ${S}
    NOCONFIGURE=1 ./autogen.sh
    cd -
}

