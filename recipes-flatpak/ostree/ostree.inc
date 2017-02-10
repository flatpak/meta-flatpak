DESCRIPTION = "Versioned Operating System Repository."
HOMEPAGE = "https://ostree.readthedocs.io"
LICENSE = "LGPLv2.1"

LIC_FILES_CHKSUM = "file://COPYING;md5=5f30f0716dfdd0d91eb439ebec522ec2"

SRC_URI = " \
    gitsm://git@github.com/ostreedev/ostree;protocol=https \
    file://0001-autogen.sh-fall-back-to-no-gtkdocize-if-it-is-there-.patch \
    file://0001-libostree-fix-missing-macros-when-compiling-without-.patch \
"

SRCREV = "6517a8a27a1386e7cb5482e7cb2919fe92721ccf"

PV = "2017.1+git${SRCPV}"
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
