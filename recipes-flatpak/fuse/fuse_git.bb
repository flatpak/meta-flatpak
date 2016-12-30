DESCRIPTION = "Filesystem in Userspace."
HOMEPAGE = "http://fuse.sf.net"
LICENSE = "LGPLv2.1|GPLv2"
LIC_FILES_CHKSUM = " \
    file://COPYING.LIB;md5=4fbd65380cdd255951079008b364516c \
    file://COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263 \
"

# Lazy bastards' cheat to get iconv
DEPENDS = "glib-2.0"

SRC_URI = "git://git@github.com/libfuse/libfuse;protocol=https;branch=fuse-2_9_bugfix"
# Flatpak ATM requires fuse 2.9. 3.0 does not provide a backward-compatible
# interface so we pick the 2.9 branch for the time being. Once flatpak
# switches to 3.0 we can do so as well.
#SRCREV = "44346a9885cb4567ea29c4cb089b1f249c0e46c2"
SRCREV = "df499bf1ce634f6e67d4d366c4475d32143f00f0"

PV = "2016.8+git${SRCPV}"
S = "${WORKDIR}/git"

PACKAGES += "${PN}-devices"

FILES_${PN}-devices = "/dev/fuse"

inherit autotools pkgconfig
AUTO_LIBNAME_PKGS = ""

# possible package configurations
PACKAGECONFIG ??= ""
FUSE_MOUNT_PATH = "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', \
                   '/usr/sbin', '/sbin', d)}"

do_configure_prepend() {
    cd ${S}
    export MOUNT_FUSE_PATH="${FUSE_MOUNT_PATH}"
    ./makeconf.sh
    cd -
}

#do_install_append() {
#    [ -n "${D}" ] && \
#        cp ${D}/${libdir}/pkgconfig/fuse3.pc ${D}/${libdir}/pkgconfig/fuse.pc
#}

EXTRA_OECONF_class-target += " \
    --enable-lib \
    --enable-util \
    --disable-example \
    --disable-mtab \
"

EXTRA_OECONF_class-native += " \
    --enable-lib \
    --enable-util \
    --disable-example \
    --disable-mtab \
"

BBCLASSEXTEND = "native"
