# Enable flatpak application support.
#
# Include this file into your local.conf or into a profile-specific distro
# config file if you want to add support for flatpak-based applications in
# your images.

# Enable flatpak and its dependencies.
DISTRO_FEATURES_append = " pam usrmerge flatpak"

# Enable user D-Bus session bus.
PACKAGECONFIG_append_pn-dbus = " user-session"

# This could/should be in our distro.conf... 2.4.x is GPLv3.
PREFERRED_VERSION_gnupg = "${@bb.utils.contains('DISTRO_FEATURES', 'flatpak', \
                                                '1.%', '%', d)}"
