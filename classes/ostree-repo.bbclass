inherit ostree-variables

addtask do_ostreeimage after do_rootfs do_initramfs before do_image_complete

do_ostreeimage () {
    OSTREEBASE="${@d.getVar('OSTREEBASE')}"
    OSTREE_REPO="${@d.getVar('OSTREE_REPO')}"
    OSTREE_DISTRO="${@d.getVar('OSTREE_DISTRO')}"
    OSTREE_KERNEL="${@d.getVar('OSTREE_KERNEL')}"
    OSTREE_INITRD="${@d.getVar('OSTREE_INITRD')}"
    OSTREE_ARCH="${@d.getVar('OSTREE_ARCH')}"
    OSTREE_SYSROOT="${@d.getVar('IMAGE_ROOTFS')}"
    GPG_HOME=foo
    GPG_ID=bar

    $OSTREEBASE/scripts/ostree-repo.sh \
        --repo-path $OSTREE_REPO \
        --repo-mode bare-user \
        --distro $OSTREE_DISTRO \
        --gpg-home $GPG_HOME \
        --gpg-id $GPG_ID \
        --image-dir $OSTREE_SYSROOT \
        --image-arch $OSTREE_ARCH \
        --image-tmp $OSTREE_SYSROOT.ostree-tmp \
        --kernel $OSTREE_KERNEL \
        --initrd $OSTREE_INITRD
}

do_ostreeimage[depends] += " \
    binutils-native:do_populate_sysroot \
    ostree-native:do_populate_sysroot \
    virtual/kernel:do_deploy \
    initramfs-framework:do_populate_sysroot \
    ${INITRD_IMAGE}:do_image_complete \
"
