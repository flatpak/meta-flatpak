include ../meta/recipes-core/images/core-image-minimal-dev.bb

SUMMARY = "Flatpak SDK image for the target- and compatible devices."

# Merge /usr with / (breaks gobject introspection data generation).
DISTRO_FEATURES_append = " usrmerge"
DISTRO_FEATURES_BACKFILL_CONSIDERED += "gobject-introspection-data"

# Use systemd instead of SysV-init, don't install initscripts.
DISTRO_FEATURES_append = " systemd"
DISTRO_FEATURES_BACKFILL_CONSIDERED += "sysvinit"
VIRTUAL-RUNTIME_init_manager = "systemd"
VIRTUAL-RUNTIME_initscripts = ""

# Pull in development tools.
IMAGE_FEATURES_append = " ssh-server-openssh tools-sdk tools-profile"

# Pull in flatpak and its dependencies.
IMAGE_INSTALL_append = " flatpak"

