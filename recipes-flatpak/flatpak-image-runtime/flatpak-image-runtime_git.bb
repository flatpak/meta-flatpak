SUMMARY = "A systemd service to set up fake flatpak runtimes for the image."
DESCRIPTION = "This package provides a systemd service that fakes flatpak \
runtimes for the currently running image, using read-only bind mounts."
HOMEPAGE = "https://github.com/klihub/flatpak-image-runtime"
SECTION = "misc"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

SRC_URI = " \
  git://git@github.com/klihub/flatpak-image-runtime.git;protocol=http;branch=master \
"

SRCREV = "94e4b53500ef5767bb00455e6be81235eea7dc65"

DEPENDS = "systemd"

inherit autotools pkgconfig systemd flatpak-variables

S = "${WORKDIR}/git"

FILES_${PN} = " \
    ${datadir}/flatpak-image-runtime \
    ${systemd_unitdir}/system/flatpak-current-runtime.service \
    ${systemd_unitdir}/system/flatpak-distro-runtime.service \
"

SYSTEMD_SERVICE_${PN} = " \
    flatpak-current-runtime.service \
    flatpak-distro-runtime.service \
"

EXTRA_OECONF += " \
            --with-systemdunitdir=${systemd_unitdir} \
            --with-org="iot.${DISTRO}" \
            --with-arch=${arch} \
            --with-current=${FLATPAK_CURRENT} \
            --with-distro-version=${FLATPAK_VERSION} \
"

do_configure_prepend () {
    FLATPAK_ROOTFS="${@d.getVar('FLATPAK_ROOTFS', False)}"
    FLATPAK_CURRENT="${@d.getVar('FLATPAK_CURRENT', False)}"
    FLATPAK_ARCH="${@d.getVar('FLATPAK_ARCH', False)}"
    FLATPAK_VERSION="${@d.getVar('FLATPAK_VERSION', False)}"

    case $FLATPAK_ARCH in
        intel*64) arch=x86_64;;
        intel*32) arch=x86_32;;
        intel*)   arch=x86;;
        *x86*64)  arch=x86_64;;
        *x86*32)  arch=x86_32;;
        *x86*)    arch=x86;;
        *)        arch=$FLATPAK_ARCH;;
    esac

    cd ${S}
        NOCONFIGURE=1 ./bootstrap
    cd -
}

