# These are our top layer directory, OSTree-compatible rootfs path,
# primary per-build OSTree repository and machine architecture to use
# in tagging versions in the repository. These are not meant to be
# overridden.
OSTREEBASE    = "${FLATPAKBASE}"
OSTREE_ROOTFS = "${IMAGE_ROOTFS}.ostree"
OSTREE_REPO   = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.ostree"
OSTREE_ARCH   = "${@d.getVar('TARGET_ARCH_MULTILIB_ORIGINAL') \
                       if d.getVar('MPLPREFIX') else d.getVar('TARGET_ARCH')}"

# This is where we export our builds in archive-z2 format. This repository
# can be exposed over HTTP for clients to pull in upgrades from. By default
# it goes under the top build directory.
OSTREE_EXPORT ?= "${TOPDIR}/${IMAGE_BASENAME}.ostree"

# This is where our GPG keyring is generated/located at and the default
# key ID we use to sign (commits in) the repository.
OSTREE_GPGDIR ?= "${TOPDIR}/gpg"
OSTREE_GPGID  ?= "${@d.getVar('DISTRO').replace(' ', '_') + '-signing@key'}"

# OSTree remote (HTTP URL) where updates will be published.
OSTREE_REMOTE ?= "${@'http://updates.refkit.org/ostree/' + \
                        d.getVar('IMAGE_BASENAME').split('-ostree')[0]}"
