require flatpak.inc
inherit pkgconfig native autotools gettext gobject-introspection

DEPENDS = " \
    glib-2.0-native libsoup-2.4-native json-glib-native libarchive-native \
    elfutils-native fuse-native ostree-native \
    libassuan-native libgpg-error-native bubblewrap-native \
"

BBCLASSEXTEND = "native"
