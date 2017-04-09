# Support for OSTree-upgradable images.
#
# This class adds support for building ostree image variants. It is an
# addeddum to refkit-image.bbclass and is supposed to be inherited by it.
#
# An ostree image variant adds to the base image bitbake-time support for
#
#     - building OSTree-enabled images
#     - populating a per-build OSTree repository with the image
#     - publishing builds to an HTTP-serviceable repository
#
# The ostree image variant adds to the base image runtime support for
#
#     - boot-time selection of the most recent rootfs tree
#     - booting an OSTree enabled image into a rootfs
#     - pulling in image upgrades using OSTree
#
###########################################################################

# Declare an image feature for OSTree-upgradeable images.
IMAGE_FEATURES[validitems] += " \
    ostree \
"

# Declare a packagegroup with all the bits for the ostree image features.
FEATURE_PACKAGES_ostree = " \
    packagegroup-ostree \
"

#
# Define our image variants for OSTree support.
#
# - ostree variant:
#     Adds the necessary runtime bits for OSTree support. Using this
#     image on a device makes it possible to pull in updates to the
#     base distro using OSTree. Additionally, during bitbake images
#     will be exported to an OSTree repository for consumption by
#     devices running an ostree image variant.
#

# ostree variant: an image that can update itself using OSTree.
IMAGE_VARIANT[ostree] = "ostree"

BBCLASSEXTEND = "imagevariant:ostree"

###########################################################################

# Inherit (variables for our) ostree configuration
inherit ostree-config

# Take a pristine rootfs as input, shuffle its layout around to make it
# OSTree-compatible, commit the rootfs into a per-build bare-user OSTree
# repository, and finally produce an OSTree-enabled rootfs by cloning
# and checking out the rootfs as an OSTree deployment.
fakeroot do_ostree_prepare_rootfs () {
    DISTRO="${@d.getVar('DISTRO')}"
    MACHINE="${@d.getVar('MACHINE')}"
    TMPDIR="${@d.getVar('TMPDIR')}"
    IMAGE_ROOTFS="${@d.getVar('IMAGE_ROOTFS')}"
    IMAGE_BASENAME="${@d.getVar('IMAGE_BASENAME')}"
    OSTREEBASE="${@d.getVar('OSTREEBASE')}"
    OSTREE_REPO="${@d.getVar('OSTREE_REPO')}"
    OSTREE_ROOTFS="${@d.getVar('IMAGE_ROOTFS')}.ostree"
    OSTREE_EXPORT="${@d.getVar('OSTREE_EXPORT')}"
    OSTREE_ARCH="${@d.getVar('OSTREE_ARCH')}"
    OSTREE_GPGDIR="${@d.getVar('OSTREE_GPGDIR')}"
    OSTREE_GPGID="${@d.getVar('OSTREE_GPGID')}"

    echo "DISTRO=$DISTRO"
    echo "MACHINE=$MACHINE"
    echo "TMPDIR=$TMPDIR"
    echo "IMAGE_ROOTFS=$IMAGE_ROOTFS"
    echo "IMAGE_BASENAME=$IMAGE_BASENAME"
    echo "OSTREEBASE=$OSTREEBASE"
    echo "OSTREE_REPO=$OSTREE_REPO"
    echo "OSTREE_ROOTFS=$OSTREE_ROOTFS"
    echo "OSTREE_EXPORT=$OSTREE_EXPORT"
    echo "OSTREE_ARCH=$OSTREE_ARCH"
    echo "OSTREE_GPGDIR=$OSTREE_GPGDIR"
    echo "OSTREE_GPGID=$OSTREE_GPGID"

    # bail out if this does not look like an -ostree image variant
    if ${@bb.utils.contains('IMAGE_FEATURES','ostree', 'true','false', d)}; then
        echo "OSTree: image $IMAGE_BASENAME is an ostree variant"
    else
        echo "OSTree: image $IMAGE_BASENAME is not an ostree variant"
        return 0
    fi

    # Generate repository signing GPG keys, if we don't have them yet.
    $OSTREEBASE/scripts/gpg-keygen.sh \
        --home $OSTREE_GPGDIR \
        --id $OSTREE_GPGID \
        --base "${OSTREE_GPGID%%@*}"

    # Save (signing) public key for the repo.
    pubkey=${OSTREE_GPGID%%@*}.pub
    if [ ! -e ${IMGDEPLOYDIR}/$pubkey -a -e ${TOPDIR}/$pubkey ]; then
        echo "Saving OSTree repository signing key $pubkey"
        cp -v ${TOPDIR}/$pubkey ${IMGDEPLOYDIR}
    fi

    $OSTREEBASE/scripts/mk-ostree.sh -v -v \
        --distro $DISTRO \
        --arch $OSTREE_ARCH \
        --machine $MACHINE \
        --src $IMAGE_ROOTFS \
        --dst $OSTREE_ROOTFS \
        --repo $OSTREE_REPO \
        --export $OSTREE_EXPORT \
        --tmpdir $TMPDIR \
        --gpg-home $OSTREE_GPGDIR \
        --gpg-id $OSTREE_GPGID \
        --overwrite \
        prepare-sysroot export-repo
}

do_ostree_prepare_rootfs[depends] += " \
    binutils-native:do_populate_sysroot \
    ostree-native:do_populate_sysroot \
"

addtask do_ostree_prepare_rootfs after do_rootfs before do_image


# Take a per-build OSTree bare-user repository and export it to an
# archive-z2 repository which can then be exposed over HTTP for
# OSTree clients to pull in upgrades from.
fakeroot do_ostree_publish_rootfs () {
    DISTRO="${@d.getVar('DISTRO')}"
    OS_VERSION="${@d.getVar('OS_VERSION')}"
    MACHINE="${@d.getVar('MACHINE')}"
    TMPDIR="${@d.getVar('TMPDIR')}"
    IMAGE_ROOTFS="${@d.getVar('IMAGE_ROOTFS')}"
    IMAGE_BASENAME="${@d.getVar('IMAGE_BASENAME')}"
    OSTREEBASE="${@d.getVar('OSTREEBASE')}"
    OSTREE_REPO="${@d.getVar('OSTREE_REPO')}"
    OSTREE_ROOTFS="${@d.getVar('IMAGE_ROOTFS')}.ostree"
    OSTREE_EXPORT="${@d.getVar('OSTREE_EXPORT')}"
    OSTREE_ARCH="${@d.getVar('OSTREE_ARCH')}"
    OSTREE_GPGDIR="${@d.getVar('OSTREE_GPGDIR')}"
    OSTREE_GPGID="${@d.getVar('OSTREE_GPGID')}"

    echo "DISTRO=$DISTRO"
    echo "OS_VERSION=$OS_VERSION"
    echo "MACHINE=$MACHINE"
    echo "TMPDIR=$TMPDIR"
    echo "IMAGE_ROOTFS=$IMAGE_ROOTFS"
    echo "IMAGE_BASENAME=$IMAGE_BASENAME"
    echo "OSTREEBASE=$OSTREEBASE"
    echo "OSTREE_REPO=$OSTREE_REPO"
    echo "OSTREE_ROOTFS=$OSTREE_ROOTFS"
    echo "OSTREE_EXPORT=$OSTREE_EXPORT"
    echo "OSTREE_ARCH=$OSTREE_ARCH"
    echo "OSTREE_GPGDIR=$OSTREE_GPGDIR"
    echo "OSTREE_GPGID=$OSTREE_GPGID"

    # bail out if this does not look like an -ostree image variant or we're
    # not supposed to publish
    if ${@bb.utils.contains('IMAGE_FEATURES','ostree', 'false','true', d)}; then
        return 0
    fi

    if [ -z "${@d.getVar('OSTREE_EXPORT')}" ]; then
        echo "OSTree: OSTREE_EXPORT repository not set, not publishing."
        return 0
    fi

    REAL_VERSION=$(cat $IMAGE_ROOTFS/etc/version)
    OSTREE_REPO="${OSTREE_REPO%-[0123456789]*.ostree}-$REAL_VERSION.ostree"
    echo "OSTREE_REPO=$OSTREE_REPO"

    $OSTREEBASE/scripts/mk-ostree.sh -v -v \
        --distro $DISTRO \
        --arch $OSTREE_ARCH \
        --machine $MACHINE \
        --repo $OSTREE_REPO \
        --export $OSTREE_EXPORT \
        --gpg-home $OSTREE_GPGDIR \
        --gpg-id $OSTREE_GPGID \
        --overwrite \
        export-repo
}

addtask do_ostree_publish_rootfs after do_ostree_prepare_rootfs before do_image
