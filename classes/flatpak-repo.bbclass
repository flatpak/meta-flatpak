# flatpak requires merged / and usr, systemd, and PAM. Unfortunately
# distro features cannot be reliably forced, not even by a layer. Use
# the next best thing.

inherit distro_features_check
REQUIRED_DISTRO_FEATURES_append = " usrmerge systemd pam"


FLATPAK_TOPDIR = "${TOPDIR}"
FLATPAK_TMPDIR = "${TOPDIR}/tmp-glibc"
FLATPAK_ROOTFS = "${IMAGE_ROOTFS}"
FLATPAK_ARCH   = "${MACHINE}"
FLATPAK_REPO   = "${IMGDEPLOYDIR}/${IMAGE_BASENAME}-${BUILD_ID}.flatpak"
FLATPAK_EXPORT = "${TOPDIR}/${IMAGE_BASENAME}.flatpak"
FLATPAK_GPGDIR = "${TOPDIR}/gpg"
FLATPAK_GPGOUT = "iot-refkit"
FLATPAK_GPGID  = "iot-refkit@key"
FLATPAK_DISTRO = "${DISTRO}"

do_flatpakrepo () {
   #echo "WORKDIR:          ${@d.getVar('WORKDIR')}"
   #echo "DEPLOY_DIR_IMAGE: ${@d.getVar('DEPLOY_DIR_IMAGE')}"
   #echo "IMGDEPLOYDIR:     ${@d.getVar('IMGDEPLOYDIR')}"
   echo "IMAGE_BASENAME:   ${@d.getVar('IMAGE_BASENAME')}"
   echo "IMAGE_NAME:       ${@d.getVar('IMAGE_NAME')}"
   #echo "BUILD_ID:         ${@d.getVar('BUILD_ID')}"
   #echo "D:                ${@d.getVar('D')}"
   #echo "S:                ${@d.getVar('S')}"
   #echo "FLATPAK_DISTRO:   ${@d.getVar('FLATPAK_DISTRO')}"
   #
   #return 0

   # Bail out early if flatpak is not enabled.
   HAS_FLATPAK="${@bb.utils.contains('IMAGE_FEATURES', 'flatpak', 'yes', '', d)}"
   if [ "$HAS_FLATPAK" != "yes" ]; then
       echo "Flatpak not enabled in image, skip repo generation..."
       return 0
   fi

   FLATPAK_TOPDIR="${@d.getVar('FLATPAK_TOPDIR')}"
   FLATPAK_TMPDIR="${@d.getVar('FLATPAK_TMPDIR')}"
   FLATPAK_ROOTFS="${@d.getVar('FLATPAK_ROOTFS')}"
   FLATPAK_ARCH="${@d.getVar('FLATPAK_ARCH')}"
   FLATPAK_GPGDIR="${@d.getVar('FLATPAK_GPGDIR')}"
   FLATPAK_GPGOUT="${@d.getVar('FLATPAK_GPGOUT')}"
   FLATPAK_GPGID="${@d.getVar('FLATPAK_GPGID')}"
   FLATPAK_REPO="${@d.getVar('FLATPAK_REPO')}"
   FLATPAK_EXPORT="${@d.getVar('FLATPAK_EXPORT')}"
   FLATPAK_DISTRO="${@d.getVar('FLATPAK_DISTRO')}"
   BUILD_ID="${@d.getVar('BUILD_ID')}"

   # Guesstimate whether this is runtime or an SDK image.
   HAS_SDK="${@bb.utils.contains('IMAGE_FEATURES', 'tools-sdk', 'yes', '', d)}"
   if [ "$HAS_SDK" = "yes" ]; then
       RUNTIME_TYPE=sdk
   else
       RUNTIME_TYPE=runtime
   fi

   VERSION=$(cat $FLATPAK_ROOTFS/etc/version)
   FLATPAKBASE="${@d.getVar('FLATPAKBASE')}"

   # Generate repo signing GPG keys if we don't have them yet.
   if [ ! -d $FLATPAK_GPGDIR ]; then
       $FLATPAKBASE/scripts/gpg-keygen.sh \
           --home $FLATPAK_GPGDIR \
           --output $FLATPAK_GPGOUT \
           --id $FLATPAK_GPGID
   else
       echo "Will (re)use existing GPG keys from $FLATPAK_GPGDIR."
   fi

   # Generate/populate flatpak/OSTree repository
   $FLATPAKBASE/scripts/populate-repo.sh \
       --gpg-home $FLATPAK_GPGDIR \
       --gpg-id $FLATPAK_GPGID \
       --repo-path $FLATPAK_REPO \
       --repo-mode bare-user \
       --repo-export $FLATPAK_EXPORT \
       --image-dir $FLATPAK_ROOTFS \
       --image-type $RUNTIME_TYPE \
       --image-arch $FLATPAK_ARCH \
       --image-version $VERSION \
       --image-buildid $BUILD_ID \
       --tmp-dir $FLATPAK_TMPDIR
}

do_flatpakrepo[depends] += "ostree-native:do_populate_sysroot flatpak-native:do_populate_sysroot"

SSTATETASKS += "do_flatpakrepo"
do_flatpakrepo[sstate-inputdirs]  = "${IMGDEPLOYDIR}"
do_flatpakrepo[sstate-outputdirs] = "${DEPLOY_DIR_IMAGE}"

python do_flatpakrepo_setscene () {
    sstate_setscene(d)
}

addtask do_flatpakrepo_setscene
addtask flatpakrepo after do_rootfs before do_image

#
# Alternatively we could treat flatpak repositories as just another
# image type. Commenting the explicit addtask above and uncommenting
# the remaining assignments below accomplishes just that.
#
# However, at the moment (our set of) ostree (commands) fails to run
# successfully under pseudo. The initial repo creation and population
# works, but pull fails. I *think* the problem might be that pseudo
# fails to properly handle/track directory-relative locking done by
# fcntl(fd, F_OFD_{[SG]ETLK,SETLKW}, ...).
#
# So we go with the explicit task for the time being... which is also
# much better from the flatpak repo creation speed point of view (no
# pseudo).
#
#IMAGE_CMD_flatpak = "do_flatpakrepo"
#IMAGE_FSTYPES_append = " flatpak"
