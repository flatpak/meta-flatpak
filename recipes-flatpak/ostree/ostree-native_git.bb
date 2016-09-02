require ostree.inc
inherit native

DEPENDS = " \
    glib-2.0-native libsoup-2.4 gpgme-native e2fsprogs-native \
    libpcap-native fuse-native libarchive-native zlib-native xz-native \
"

EXTRA_OECONF_class-native += "--disable-man"
