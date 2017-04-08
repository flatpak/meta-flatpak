FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI += " \
    file://ostree \
"

PACKAGE_INSTALL += " \
    initramfs-module-debug \
    ${PN}-module-ostree \
"

PACKAGES += " \
    ${PN}-module-ostree \
"

FILES_${PN}-module-ostree = "/init.d/91-ostree"

do_install_append() {
    # ostree
    install -m 0755 ${WORKDIR}/ostree ${D}/init.d/91-ostree
}