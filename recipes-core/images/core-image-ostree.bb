# Hmm... maybe we should just copy and adjust the content from
# core-image-minimal instead...

include ../meta/recipes-core/images/core-image-minimal.bb

# Enable flatpak and SSH server distro features.
IMAGE_FEATURES_append = " ostree ssh-server-openssh"

# And pull in the flatpak bits.
inherit ostree-image

# Well... not really core-image-minimal any more.
SUMMARY = "A OSTree test image."
