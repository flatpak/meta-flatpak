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
   if [ "$HAS_FLATPAK" = "y" ]; then
       echo "Flatpak not enabled in image, skip key generation..."
       return 0
   fi

   FLATPAKBASE="${@d.getVar('FLATPAKBASE')}"
   FLATPAK_GPGDIR="${@d.getVar('FLATPAK_GPGDIR')}"
   FLATPAK_GPGOUT="${@d.getVar('FLATPAK_GPGOUT')}"
   FLATPAK_GPGID="${@d.getVar('FLATPAK_GPGID')}"

   # Generate repo signing GPG keys if we don't have them yet.
   if [ ! -d $FLATPAK_GPGDIR ]; then
       $FLATPAKBASE/scripts/gpg-keygen.sh \
           --home $FLATPAK_GPGDIR \
           --output $FLATPAK_GPGOUT \
           --id $FLATPAK_GPGID
   else
       echo "Will (re)use existing GPG keys from $FLATPAK_GPGDIR."
   fi
}

do_flatpakkeys[depends] += " \
    gnupg-native:do_populate_sysroot \
"

do_flatpakkeys[vardeps] += " \
    FLATPAK_GPGDIR \
    FLATPAK_GPGOUT \
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
