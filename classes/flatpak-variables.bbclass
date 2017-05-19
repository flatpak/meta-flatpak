
FLATPAK_TOPDIR  = "${TOPDIR}"
FLATPAK_TMPDIR  = "${TMPDIR}"
FLATPAK_ROOTFS  = "${IMAGE_ROOTFS}"
FLATPAK_ARCH    = "${MACHINE}"
FLATPAK_REPO    = "${IMGDEPLOYDIR}/${IMAGE_BASENAME}-${BUILD_ID}.flatpak"
FLATPAK_DISTRO  = "${DISTRO}"

# This is where we export our builds (matching FLATPAK_IMAGE_PATTERN) in
# archive-z2 format. This repository can be exposed over HTTP for clients.
# By default it goes under the top build directory.
FLATPAK_EXPORT ?= "${TOPDIR}/${IMAGE_BASENAME}.flatpak"

# This is where our GPG keyring is generated/located and the default
# key ID we use to sign (commits in) the repository.
FLATPAK_GPGDIR ?= "${TOPDIR}/gpg"
FLATPAK_GPGID  ?= "${@(d.getVar('DISTRO', False) or \
                         'unknown').replace(' ', '_') + '-signing@key'}"

# By default we publish two 'version' branches in our flatpak repositories:
# One is a rolling release, the 'current' version. The other is derived from
# the distro version, by default stripping the trailing +snapshot.* suffix.
# flatpak repositories. One is 'current. These are available in all builds,
# not just image builds. The third one, build, is only available in image
# builds.
FLATPAK_CURRENT ?= "current"
FLATPAK_VERSION ?= "${@(d.getVar('DISTRO_VERSION', False) or \
                                                  0.0).split('+snapshot')[0]}"
FLATPAK_BUILD    = "${BUILD_ID}"


# By default we trigger flatpak repository population/generation only
# for images that we configured to be suitable for flatpak-building
# applications. These images will have a basename matching the value
# of FLATPAK_IMAGE_PATTERN.
#
# You can override this to generate flatpak repositories also for
# other images by overriding this variable. You can use either a
# a regexp suitable for grep or a shell globbing pattern that will
# match your image name. For globbing patterns, the value should be
# prefixed with 'glob:'.
FLATPAK_IMAGE_PATTERN ?= 'glob:*-flatpak-sdk'

# You can pre-declare flatpak repositories/remotes for flatpak-enabled
# images. Devices running such an image will monitor the remotes for
# for flatpak applications. Any application found will be considered for
# automatic installation and update to the device.
#
# To declare a flatpak remote, you have to
#   1) give the remote a name
#   2) provide a repository URL and GPG public key for the remote
#   3) associate a user with (IOW create a user for) the remote
#
# The variable FLATPAK_APP_REPOS lists the names of the remotes
# you want to pre-declare in the image. For every remote <r> you
# have to provide an <r>.url and <r>.key file in ${TOPDIR}/conf,
# with the HTTP URL and GPG public key for the remote as content.
#
# Similarly, you have to provide an (/etc/)passwd and (/etc/)group
# entry for every remote in the following passwd and group fragment
# files:
#
#    ${TOPDIR}/conf/flatpak-passwd
#    ${TOPDIR}/conf/flatpak-group
#
# The GECOS entry for user <u> associated with remote <r> must be
#
#    'flatpak user for <r>'
#
#
# By default FLATPAK_APP_REPOS is set to empty and no repositories are
# pre-declared.
FLATPAK_APP_REPOS ?= ""
