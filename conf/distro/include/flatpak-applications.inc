# Enable flatpak application support.
#
# Include this file into your local.conf or into a profile-specific distro
# config file if you want to add support for flatpak-based applications in
# your images.

# Enable flatpak and its dependencies.
DISTRO_FEATURES_append = " pam usrmerge systemd flatpak"

# Enable user D-Bus session bus.
PACKAGECONFIG_append_pn-dbus = " user-session"

# This could/should be in our distro.conf... 2.4.x is GPLv3.
PREFERRED_VERSION_gnupg = "1.%"

# Disable sysvinit completely.
VIRTUAL-RUNTIME_init_manager = "systemd"
DISTRO_FEATURES_BACKFILL_CONSIDERED = "sysvinit"
VIRTUAL-RUNTIME_initscripts = ""
