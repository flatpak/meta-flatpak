# flatpak requires merged / and usr, systemd, and PAM. Unfortunately
# distro features cannot be reliably forced, not even by a layer. Use
# the next best thing.

inherit distro_features_check
REQUIRED_DISTRO_FEATURES_append = " usrmerge systemd pam"

inherit flatpak-variables

# Declare our extra test cases. Also declare a few extra variables
# we (might eventually) use in our test cases, so we want them
# exported and accessible in builddata. These won't have any effect
# unless test-iot.bbclass in inherited by local.conf or the images.
IOTQA_EXTRA_TESTS += " \
    oeqa.runtime.sanity.flatpak:refkit-image-minimal-flatpak-sdk \
"

IOTQA_EXTRA_BUILDDATA += " \
    IMAGE_BASENAME \
    FLATPAK_IMAGE_PATTERN \
"

#
# generating/populating flatpak repositories from/for images
#

do_flatpakrepo () {
   IMAGE_BASENAME="${@d.getVar('IMAGE_BASENAME', False)}"
   FLATPAK_IMAGE_PATTERN="${@d.getVar('FLATPAK_IMAGE_PATTERN', False)}"

   echo "Flatpak repository population:"
   echo "  * IMAGE_BASENAME: $IMAGE_BASENAME"
   echo "  * IMAGE_NAME:     ${@d.getVar('IMAGE_NAME', False)}"

   # Bail out if this looks like an initramfs image.
   case $IMAGE_BASENAME in
       *initramfs*) return 0;;
   esac

   # Bail out early if flatpak is not enabled for this image.
   if [ "${FLATPAK_IMAGE_PATTERN%%:*}" == "glob" ]; then
       case $IMAGE_BASENAME in
           ${FLATPAK_IMAGE_PATTERN#glob:}) repo_enabled=yes;;
           *)                              repo_enabled="";;
       esac
   else
       repo_enabled=$(echo $IMAGE_BASENAME | grep "$FLATPAK_IMAGE_PATTERN" || :)
   fi

   if [ -z "$repo_enabled" ]; then
       echo "Flatpak not enabled for $IMAGE_BASENAME, skip repo generation..."
       return 0
   fi

   case $IMAGE_BASENAME in
       *flatpak-sdk*)     FLATPAK_RUNTIME=sdk;;
       *flatpak-runtime*) FLATPAK_RUNTIME=runtime;;
       *)                 FLATPAK_RUNTIME=runtime;;
   esac

   FLATPAKBASE="${@d.getVar('FLATPAKBASE', False)}"
   FLATPAK_TOPDIR="${@d.getVar('FLATPAK_TOPDIR', False)}"
   FLATPAK_TMPDIR="${@d.getVar('FLATPAK_TMPDIR', False)}"
   FLATPAK_ROOTFS="${@d.getVar('FLATPAK_ROOTFS', False)}"
   FLATPAK_ARCH="${@d.getVar('FLATPAK_ARCH', False)}"
   FLATPAK_GPGDIR="${@d.getVar('FLATPAK_GPGDIR', False)}"
   FLATPAK_GPGID="${@d.getVar('FLATPAK_GPGID', False)}"
   FLATPAK_REPO="${@d.getVar('FLATPAK_REPO', False)}"
   FLATPAK_DISTRO="${@d.getVar('FLATPAK_DISTRO', False)}"
   FLATPAK_RUNTIME_IMAGE="${@d.getVar('FLATPAK_RUNTIME_IMAGE', False)}"
   FLATPAK_CURRENT="${@d.getVar('FLATPAK_CURRENT', False)}"
   FLATPAK_VERSION="${@d.getVar('FLATPAK_VERSION', False)}"

   VERSION=$(cat $FLATPAK_ROOTFS/etc/version)

   # Generate repository signing GPG keys, if we don't have them yet.
   $FLATPAKBASE/scripts/gpg-keygen.sh \
       --home $FLATPAK_GPGDIR \
       --id $FLATPAK_GPGID \
       --base "${FLATPAK_GPGID%%@*}"

   # Save (signing) public key for the repo.
   pubkey=${FLATPAK_GPGID%%@*}.pub
   if [ ! -e ${IMGDEPLOYDIR}/$pubkey -a -e ${TOPDIR}/$pubkey ]; then
       echo "Saving flatpak repository signing key $pubkey"
       cp -v ${TOPDIR}/$pubkey ${IMGDEPLOYDIR}
   fi

   # Generate/populate flatpak/OSTree repository
   $FLATPAKBASE/scripts/populate-repo.sh \
       --gpg-home $FLATPAK_GPGDIR \
       --gpg-id $FLATPAK_GPGID \
       --repo-path $FLATPAK_REPO \
       --repo-mode bare-user \
       --repo-org "iot.$FLATPAK_DISTRO" \
       --image-dir $FLATPAK_ROOTFS \
       --image-base $IMAGE_BASENAME \
       --image-type $FLATPAK_RUNTIME \
       --image-arch $FLATPAK_ARCH \
       --image-version $VERSION \
       --distro-version $FLATPAK_VERSION \
       --rolling-version $FLATPAK_CURRENT \
       --tmp-dir $FLATPAK_TMPDIR

}


do_flatpakrepo[depends] += " \
    ostree-native:do_populate_sysroot \
    flatpak-native:do_populate_sysroot \
    gnupg-native:do_populate_sysroot \
"

do_flatpakrepo[vardeps] += " \
    FLATPAK_GPGDIR \
    FLATPAK_GPGID \
    FLATPAK_REPO \
    FLATPAK_DISTRO \
    FLATPAK_CURRENT \
    FLATPAK_ROOTFS \
    IMAGE_BASENAME \
    FLATPAK_RUNTIME \
    FLATPAK_ARCH \
    VERSION \
"


#
# exporting image to archive-z2 repository
#
do_flatpakexport () {
   FLATPAK_EXPORT="${@d.getVar('FLATPAK_EXPORT', False)}"

   # Bail out early if no export repository is defined.
   if [ -z "$FLATPAK_EXPORT" ]; then
       echo "Flatpak repository for export not specified, skip export..."
       return 0
   fi

   IMAGE_BASENAME="${@d.getVar('IMAGE_BASENAME', False)}"
   FLATPAK_IMAGE_PATTERN="${@d.getVar('FLATPAK_IMAGE_PATTERN', False)}"

   echo "Flatpak repository exporting:"
   echo " * IMAGE_BASENAME: $IMAGE_BASENAME"
   echo " * IMAGE_NAME:     ${@d.getVar('IMAGE_NAME', False)}"

   # Bail out if this looks like an initramfs image.
   case $IMAGE_BASENAME in
       *initramfs*) return 0;;
   esac

   # Bail out early if flatpak is not enabled for this image.
   if [ "${FLATPAK_IMAGE_PATTERN%%:*}" == "glob" ]; then
       case $IMAGE_BASENAME in
           ${FLATPAK_IMAGE_PATTERN#glob:}) repo_enabled=yes;;
           *)                              repo_enabled="";;
       esac
   else
       repo_enabled=$(echo $IMAGE_BASENAME | grep "$FLATPAK_IMAGE_PATTERN" || :)
   fi

   if [ -z "$repo_enabled" ]; then
       echo "Flatpak not enabled for $IMAGE_BASENAME, skip repo export..."
       return 0
   fi

   case $IMAGE_BASENAME in
       *flatpak-sdk*)     FLATPAK_RUNTIME=sdk;;
       *flatpak-runtime*) FLATPAK_RUNTIME=runtime;;
       *)                 FLATPAK_RUNTIME=runtime;;
   esac

   FLATPAKBASE="${@d.getVar('FLATPAKBASE', False)}"
   FLATPAK_TOPDIR="${@d.getVar('FLATPAK_TOPDIR', False)}"
   FLATPAK_TMPDIR="${@d.getVar('FLATPAK_TMPDIR', False)}"
   FLATPAK_ROOTFS="${@d.getVar('FLATPAK_ROOTFS', False)}"
   FLATPAK_ARCH="${@d.getVar('FLATPAK_ARCH', False)}"
   FLATPAK_GPGDIR="${@d.getVar('FLATPAK_GPGDIR', False)}"
   FLATPAK_GPGID="${@d.getVar('FLATPAK_GPGID', False)}"
   FLATPAK_REPO="${@d.getVar('FLATPAK_REPO', False)}"
   FLATPAK_DISTRO="${@d.getVar('FLATPAK_DISTRO', False)}"
   FLATPAK_RUNTIME_IMAGE="${@d.getVar('FLATPAK_RUNTIME_IMAGE', False)}"
   FLATPAK_CURRENT="${@d.getVar('FLATPAK_CURRENT', False)}"
   FLATPAK_VERSION="${@d.getVar('FLATPAK_VERSION', False)}"

   VERSION=$(cat $FLATPAK_ROOTFS/etc/version)

   # Export to archive-z2 flatpak/OSTree repository
   $FLATPAKBASE/scripts/populate-repo.sh \
       --gpg-home $FLATPAK_GPGDIR \
       --gpg-id $FLATPAK_GPGID \
       --repo-path $FLATPAK_REPO \
       --repo-export $FLATPAK_EXPORT \
       --repo-org "iot.$FLATPAK_DISTRO" \
       --image-dir $FLATPAK_ROOTFS \
       --image-base $IMAGE_BASENAME \
       --image-type $FLATPAK_RUNTIME \
       --image-arch $FLATPAK_ARCH \
       --image-version $VERSION \
       --distro-version $FLATPAK_VERSION \
       --rolling-version $FLATPAK_CURRENT \
       --tmp-dir $FLATPAK_TMPDIR \
       export
}


#SSTATETASKS += "do_flatpakrepo"
#do_flatpakrepo[sstate-inputdirs]  = "${IMGDEPLOYDIR}"
#do_flatpakrepo[sstate-outputdirs] = "${DEPLOY_DIR_IMAGE}"
#
#python do_flatpakrepo_setscene () {
#    sstate_setscene(d)
#}
#

#addtask do_flatpakrepo_setscene

addtask do_flatpakrepo after do_rootfs before do_image_complete
addtask do_flatpakexport after do_flatpakrepo before do_image_complete



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
