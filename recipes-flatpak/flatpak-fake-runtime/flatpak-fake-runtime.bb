SUMMARY = "Fake flatpak runtime for the currently running image."
DESCRIPTION = "This package provides a systemd service that fakes flatpak \
runtime for the currently running image, using read-only bind mounts."
HOMEPAGE = "http://127.0.0.1"
SECTION = "misc"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

inherit systemd

SRC_URI = " \
    file://LICENSE-BSD \
    file://flatpak-fake-runtime.service.in \
    file://metadata.in \
    file://deploy.in \
"

S = "${WORKDIR}"

FILES_${PN} = " \
    ${datadir}/flatpak-fake-runtime \
    ${systemd_unitdir}/system/flatpak-fake-runtime.service \
"

SYSTEMD_SERVICE_${PN} = "flatpak-fake-runtime.service"

do_compile() {
    # there is probable a proper bitbake variable for arch...
    local _t='${TARGET_SYS}'
    local _v="1234567890abcdeffedcba09876543211234567890abcdeffedcba0987654321"

    cat ${S}/flatpak-fake-runtime.service.in | \
        sed "s#@ARCH@#${_t%%-*}#g;s#@VERSION@#0.0.1#g" \
            > ${S}/flatpak-fake-runtime.service

    cat ${S}/metadata.in | \
        sed "s#@ARCH@#${_t%%-*}#g;s#@VERSION@#0.0.1#g" \
            > ${S}/metadata

    cat ${S}/deploy.in | \
        sed "s#@ARCH@#${_t%%-*}#g;s#@VERSION@#0.0.1#g;s#@SHA1@#${_v}#g" \
            > ${S}/deploy
}

do_install () {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${S}/flatpak-fake-runtime.service \
        ${D}${systemd_unitdir}/system

    install -d ${D}${datadir}/flatpak-fake-runtime
    install -m 0644 ${S}/deploy   ${D}${datadir}/flatpak-fake-runtime
    install -m 0644 ${S}/metadata ${D}${datadir}/flatpak-fake-runtime
}
