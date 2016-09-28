require flatpak.inc
inherit autotools pkgconfig gettext systemd gobject-introspection

DEPENDS = " \
    glib-2.0 json-glib libsoup-2.4 libarchive elfutils fuse \
    ostree libassuan libgpg-error bubblewrap systemd \
"

RDEPENDS_${PN} = "bubblewrap"

EXTRA_OECONF += " \
    --disable-docbook-docs \
    --disable-gtk-doc-html \
    --disable-documentation \
    --disable-system-helper \
    --disable-seccomp \
    --disable-xauth \
    --with-systemdsystemunitdir=${systemd_unitdir}/system \
"

