DESCRIPTION = "Versioned Operating System Repository."
HOMEPAGE = "https://ostree.readthedocs.io"
LICENSE = "LGPLv2.1"

LIC_FILES_CHKSUM = "file://COPYING;md5=5f30f0716dfdd0d91eb439ebec522ec2"

SRC_URI = "gitsm://git@github.com/ostreedev/ostree;protocol=https"
SRCREV = "3b55db96614da63d935d641d9cb4311153b774af"

PV = "2016.8+git${SRCPV}"
S = "${WORKDIR}/git"

inherit autotools pkgconfig
AUTO_LIBNAME_PKGS = ""

# possible package configurations
PACKAGECONFIG ??= ""

do_configure_prepend() {
    pushd ${S}
    NOCONFIGURE=1 ./autogen.sh
    popd
}

EXTRA_OECONF += "--disable-man"
