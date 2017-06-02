SUMMARY = "OSTree helper/wrapper scripts et al. for IoT RefKit."

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

SRC_URI = " \
  git://git@github.com/klihub/refkit-ostree-upgrade.git;protocol=http;branch=master \
"

SRCREV = "cd4887dae318e318169d6cf718d39989160082ad"

DEPENDS = "ostree"

inherit autotools pkgconfig systemd

S = "${WORKDIR}/git"

FILES_${PN} = " \
    ${bindir}/refkit-ostree \
    ${bindir}/refkit-ostree-update \
    ${systemd_unitdir}/system/* \
"

# We want the following services enabled.
SYSTEMD_SERVICE_${PN} = " \
    ostree-patch-proc-cmdline.service \
    ostree-update.service \
    ostree-post-update.service \
"

EXTRA_OECONF += " \
            --with-systemdunitdir=${systemd_unitdir} \
"