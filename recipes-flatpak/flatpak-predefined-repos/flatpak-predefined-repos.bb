DESCRIPTION = "A package containing enough information about predefined flatpak repositories that they can be automatically taken into use on devices using the image."
HOMEPAGE = "http://127.0.0.1/"
LICENSE = "BSD-3-Clause"

LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

SRC_URI = " \
    git://git@github.com/klihub/flatpak-predefined-repos.git;protocol=https;branch=master \
"

SRCREV = "9ff652344f1d08a16b55da1aa8f6b98223adc848"

S = "${WORKDIR}/git"

inherit autotools flatpak-keys

EXTRA_OECONF += "--with-refkit-key=${FLATPAK_TOPDIR}/${FLATPAK_GPGOUT}.pub"

FILES_${PN} = " \
    ${sysconfdir}/flatpak-session/* \
"
