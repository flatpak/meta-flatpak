IMAGE_FEATURES[validitems] += " \
    ostree \
"

FEATURE_PACKAGES_ostree = " \
    packagegroup-ostree \
    ca-certificates \
"

addtask do_ostreeimage after do_rootfs do_initramfs before do_image_complete

do_ostreeimage () {
    pseudo echo "*** do_ostreeimage called ***"
}