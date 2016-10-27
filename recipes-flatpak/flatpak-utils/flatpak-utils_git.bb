DESCRIPTION = "Helper utilities for flatpak-based applications/services."
HOMEPAGE = "http://github.com/klihub/flatpak-utils"
LICENSE = "BSD-3-Clause"

LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

DEPENDS = "flatpak systemd"

SRC_URI = " \
    git://git@github.com/klihub/flatpak-utils.git;protocol=https;branch=master \
  "

SRCREV = "ce8bac25367abc4d45e6023ff52b2e55e8c8021d"

inherit autotools pkgconfig systemd

AUTO_LIBNAME_PKGS = ""

S = "${WORKDIR}/git"

# possible package configurations
PACKAGECONFIG ??= ""

FILES_${PN} = "\
    ${systemd_unitdir}/system-generators/flatpak-service-generator \
    ${libexecdir}/flatpak-utils \
    ${systemd_unitdir}/system/flatpak-sessions.target \
    ${systemd_unitdir}/system/flatpak-session@.service \
"

FILES_${PN}-dbg =+ "${base_libdir}/systemd/system-generators/.debug"

SYSTEMD_PACKAGES      += "${PN}"
SYSTEMD_SERVICE_${PN}  = "flatpak-sessions.target"
SYSTEMD_AUTO_ENABLE    = "enable"

