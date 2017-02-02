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
    # I guess ${SDKMACHINE} is the best choice here...
    local _m='${SDKMACHINE}'
    # Probably we should create two fake runtimes:
    #   - 'current': always means the actual running version
    #   - real $VERSION: inherit flatpak-variables and get it from there...
    # For now we just go with 'latest-build' to match flatpak-repo.bbclass.
    local _v='latest-build'
    local _sha="1234567890abcdeffedcba09876543211234567890abcdeffedcba0987654321"

    cat ${S}/flatpak-fake-runtime.service.in | \
        sed "s#@ARCH@#$_m#g;s#@VERSION@#$_v#g;s#@ORG@#iot.refkit#g" \
            > ${S}/flatpak-fake-runtime.service

    cat ${S}/metadata.in | \
        sed "s#@ARCH@#$_m#g;s#@VERSION@#$_v#g" \
            > ${S}/metadata

    cat ${S}/deploy.in | \
        sed "s#@ARCH@#$_m#g;s#@VERSION@#$_v#g;s#@SHA1@#$_sha#g" \
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
