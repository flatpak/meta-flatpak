require ostree.inc
inherit autotools pkgconfig systemd

DEPENDS = " \
    glib-2.0 libsoup-2.4 gpgme e2fsprogs \
    libcap fuse libarchive zlib xz \
    systemd \
"

FILES_${PN} += "${libdir}/girepository-1.0 ${datadir}/gir-1.0"

SYSTEMD_SERVICE_${PN} = "ostree-prepare-root.service ostree-remount.service"

EXTRA_OECONF-class-target += "--disable-man"
