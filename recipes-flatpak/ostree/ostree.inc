DESCRIPTION = "Versioned Operating System Repository."
HOMEPAGE = "https://ostree.readthedocs.io"
LICENSE = "LGPLv2.1"

LIC_FILES_CHKSUM = "file://COPYING;md5=5f30f0716dfdd0d91eb439ebec522ec2"

SRC_URI = " \
    gitsm://git@github.com/ostreedev/ostree;protocol=https \
    file://0001-autogen.sh-fall-back-to-no-gtkdocize-if-it-is-there-.patch \
"

SRCREV = "c9d565a5a9b435b5d3ed64a96c14a1c110698f4c"

PV = "2016.15+git${SRCPV}"
S = "${WORKDIR}/git"

inherit autotools pkgconfig gobject-introspection
AUTO_LIBNAME_PKGS = ""

# possible package configurations
PACKAGECONFIG ??= ""

do_configure_prepend() {
    pushd ${S}
    NOCONFIGURE=1 ./autogen.sh
    popd
}

EXTRA_OECONF += "--disable-man"
