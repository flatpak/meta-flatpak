
FLATPAK_TOPDIR  = "${TOPDIR}"
FLATPAK_TMPDIR  = "${TOPDIR}/tmp-glibc"
FLATPAK_ROOTFS  = "${IMAGE_ROOTFS}"
FLATPAK_ARCH    = "${MACHINE}"
FLATPAK_REPO    = "${IMGDEPLOYDIR}/${IMAGE_BASENAME}-${BUILD_ID}.flatpak"
FLATPAK_EXPORT ?= "${TOPDIR}/${IMAGE_BASENAME}.flatpak"
FLATPAK_GPGDIR ?= "${TOPDIR}/gpg"
FLATPAK_GPGOUT ?= "iot-ref-kit"
FLATPAK_GPGID  ?= "iot-ref-kit@key"
FLATPAK_DISTRO  = "${DISTRO}"

# By default we trigger flatpak repository population/generation only
# for images that can be used as flatpak SDK runtimes (i.e. images that
# has tools-sdk enabled). You can enable repository generation for pure
# runtime images by overriding ths variable and setting it to 'yes'.
FLATPAK_RUNTIME_IMAGE ?= ""
