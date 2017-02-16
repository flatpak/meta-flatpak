require ostree.inc
inherit native

DEPENDS = " \
    glib-2.0-native libsoup-2.4 gpgme-native e2fsprogs-native \
    libcap-native fuse-native libarchive-native zlib-native xz-native \
"

EXTRA_OECONF_class-native += " \
    --disable-man \
    --with-builtin-grub2-mkconfig \
"
