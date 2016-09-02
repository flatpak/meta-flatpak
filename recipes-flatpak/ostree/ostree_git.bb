DESCRIPTION = "Versioned Operating System And Binary Management."
HOMEPAGE = "https://ostree.readthedocs.io"
LICENSE = "LGPLv2.1"

LIC_FILES_CHKSUM = "file://COPYING;md5=5f30f0716dfdd0d91eb439ebec522ec2"

DEPENDS = "glib-2.0 libarchive zlib xz libpcap gpgme e2fsprogs systemd"

SRC_URI = " \
    gitsm://git@github.com/ostreedev/ostree;protocol=https \
"

SRCREV = "3b55db96614da63d935d641d9cb4311153b774af"

PV = "2016.8+git${SRCPV}"
S = "${WORKDIR}/git"

inherit autotools pkgconfig systemd
AUTO_LIBNAME_PKGS = ""

# possible package configurations
PACKAGECONFIG ??= ""

do_configure_prepend() {
    pushd ${S}
    NOCONFIGURE=1 ./autogen.sh
    popd
}

SYSTEMD_SERVICE_${PN} = "ostree-prepare-root.service ostree-remount.service"

EXTRA_OECONF_class-target += "--enable-man=no --enable-rofiles-fuse=no"

# Fuse optimization is disabled by default.
# DEPENDS_class-native += "fuse"
# EXTRA_OECONF_class-native += "--enable-man=no --enable-rofiles-fuse=yes"

EXTRA_OECONF_class-native += "--enable-man=no --enable-rofiles-fuse=no"

BBCLASSEXTEND = "native"
