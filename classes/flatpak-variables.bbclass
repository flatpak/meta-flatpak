
FLATPAK_TOPDIR  = "${TOPDIR}"
FLATPAK_TMPDIR  = "${TOPDIR}/tmp-glibc"
FLATPAK_ROOTFS  = "${IMAGE_ROOTFS}"
FLATPAK_ARCH    = "${MACHINE}"
FLATPAK_REPO    = "${IMGDEPLOYDIR}/${IMAGE_BASENAME}-${BUILD_ID}.flatpak"
FLATPAK_EXPORT ?= "${TOPDIR}/${IMAGE_BASENAME}.flatpak"
FLATPAK_GPGDIR ?= "${TOPDIR}/gpg"
FLATPAK_GPGID  ?= "${@(d.getVar('IMAGE_BASENAME') or \
                                                  '').split('-flatpak')[0]}@key"
FLATPAK_DISTRO  = "${DISTRO}"

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
