require flatpak.inc
inherit autotools pkgconfig gettext systemd gobject-introspection

DEPENDS = " \
    glib-2.0 json-glib libsoup-2.4 libarchive elfutils fuse \
    ostree libassuan libgpg-error bubblewrap systemd \
"

RDEPENDS_${PN} = "bubblewrap ca-certificates"
