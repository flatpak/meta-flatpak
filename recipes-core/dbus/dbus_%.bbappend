PACKAGECONFIG_append = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'flatpak', 'user-session', '', d)} \
"
