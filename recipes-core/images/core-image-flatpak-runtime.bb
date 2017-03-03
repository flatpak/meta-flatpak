# Hmm... maybe we should just copy and adjust the content from
# core-image-minimal instead...

include ../meta/recipes-core/images/core-image-minimal.bb

# Enable flatpak and SSH server distro features.
IMAGE_FEATURES_append = " flatpak ssh-server-openssh"

# And pull in the flatpak bits.
inherit flatpak-image

# Well... not really core-image-minimal any more.
SUMMARY = "A runtime image with flatpak support for a target device."

# Make sure we have usable certificates, and terminfo.
IMAGE_INSTALL_append = " \
    ca-certificates ncurses-terminfo \
"
