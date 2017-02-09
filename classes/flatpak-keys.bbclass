# Generate GPG signing keys for our flatpak repositories.

inherit distro_features_check
REQUIRED_DISTRO_FEATURES_append = " flatpak"

inherit flatpak-variables

#
# generation of GPG keys for signing flatpak/OSTree repositories
#

do_flatpakkeys () {
   # Bail out early if flatpak is not enabled.
   HAS_FLATPAK="${@bb.utils.contains('DISTRO_FEATURES', 'flatpak', 'y', 'n', d)}"
   if [ "$HAS_FLATPAK" != "y" ]; then
       echo "Flatpak not enabled in distro, skip key generation..."
       return 0
   fi

   FLATPAKBASE="${@d.getVar('FLATPAKBASE')}"
   IMAGE_BASENAME="${@d.getVar('IMAGE_BASENAME')}"
   FLATPAK_IMAGE_PATTERN="${@d.getVar('FLATPAK_IMAGE_PATTERN')}"
   FLATPAK_GPGDIR="${@d.getVar('FLATPAK_GPGDIR')}"
   FLATPAK_GPGID="${@d.getVar('FLATPAK_GPGID')}"

   # Bail out if we don't need a key for this image.
   if [ "${FLATPAK_IMAGE_PATTERN%%:*}" == "glob" ]; then
       case $IMAGE_BASENAME in
           ${FLATPAK_IMAGE_PATTERN#glob:}) repo_enabled=yes;;
           *)                              repo_enabled="";;
       esac
   else
       repo_enabled=$(echo $IMAGE_BASENAME | grep "$FLATPAK_IMAGE_PATTERN" || :)
   fi

   if [ -z "$repo_enabled" ]; then
       echo "Flatpak not enabled for $IMAGE_BASENAME, skip key generation..."
       return 0
   fi

   if [ -z "$FLATPAK_GPGID" ]; then
       FLATPAK_GPGID="${IMAGE_BASENAME:-unknown-image}"
   fi

   # Generate repository signing GPG keys.
   $FLATPAKBASE/scripts/gpg-keygen.sh \
       --home $FLATPAK_GPGDIR \
       --id $FLATPAK_GPGID
}

do_flatpakkeys[depends] += " \
    gnupg-native:do_populate_sysroot \
"

do_flatpakkeys[vardeps] += " \
    FLATPAK_GPGDIR \
    FLATPAK_GPGID \
"

SSTATETASKS += "do_flatpakkeys"

python do_flatpakkeys_setscene () {
    sstate_setscene(d)
}

addtask do_flatpakkeys_setscene

python () {
    if bb.data.inherits_class('image', d):
        # addtask do_flatpakkeys before do_rootfs
        bb.build.addtask('do_flatpakkeys', 'do_rootfs', '', d)
    elif bb.data.inherits_class('package', d):
        # addtask do_flatpakkeys before do_configure
        bb.build.addtask('do_flatpakkeys', 'do_configure', '', d)
    else:
        bb.warn('Neither image nor package class, don\'t know when (and why)')
        bb.warn('I should generate flatpak keys...')
}
