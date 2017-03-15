#!/bin/sh

# Print help on usage.
print_usage () {
    echo "usage: $0 [options]"
    echo ""
    echo "Take an image sysroot directory, generate an OSTree repository for"
    echo "it and create an image suitable for pulling updates from the repo."
    echo ""
    echo "The possible options are:"
    echo "  --repo-path <repo>  path of OSTree repository to create"
    echo "  --repo-mode <mode>  repository mode [archive-z2]"
    echo "  --distro            distro name to use in repository"
    echo "  --gpg-home <dir>    GPG home directory for keyring"
    echo "  --gpg-id <id>       GPG key id to use for signing"
    echo "  --image-dir <dir>   image sysroot directory"
    echo "  --image-arch <arch> image architecture"
}

# Print a fatal error and exit.
fatal () {
    echo "fatal error: $*"
    exit 1
}

# Print an error message.
error () {
    echo "error: $*"
}

# Print an informational message.
message () {
    echo "$*"
}

# Parse the command line, perform basic argument checks.
parse_command_line () {
    while [ -n "$1" ]; do
        opt=${1%=*}
        if [ "$opt" != "$1" ]; then
            arg="${1#*=}"
            narg=1
        else
            arg="$2"
            narg=2
        fi
        case $opt in
            --repo-path)
                OSTREE_REPO=$arg
                shift $narg
                ;;
            --repo-mode)
                OSTREE_MODE=$arg
                shift $narg
                ;;
            --distro)
                OSTREE_DISTRO=$arg
                shift $narg
                ;;
            --image-dir|--image-root|--image-sysroot)
                IMAGE_SYSROOT=$arg
                shift $narg
                ;;
            --image-tmp)
                IMAGE_TMPROOT=$arg
                shift $narg
                ;;
            --image-arch)
                IMAGE_ARCH=$arg
                shift $narg
                ;;

            --kernel)
                IMAGE_KERNEL=$arg
                shift $narg
                ;;
            --initramfs|--initrd)
                IMAGE_INITRAMFS=$arg
                shift $narg
                ;;

            --gpg-home)
                GPG_HOME=$arg
                shift $narg
                ;;
            --gpg-id)
                GPG_ID=$arg
                shift $narg
                ;;

            --help|-h)
                print_usage
                exit 0
                ;;

            -*)
                echo "Unknown command line option $1."
                print_usage
                exit 1
                ;;

            *)
                echo "Unknown/unused command line argument $1."
                print_usage
                exit 1
                ;;
        esac
    done

    if [ -z "$OSTREE_REPO" ]; then
        fatal "OSTree repository (--repo) not given."
    fi

    if [ -z "$IMAGE_SYSROOT" ]; then
        fatal "image sysroot directory (--image-dir) not given."
    fi

    if [ ! -d $IMAGE_SYSROOT ]; then
        fatal "no image sysroot ($IMAGE_SYSROOT) directory"
    fi

    if [ ! -f $IMAGE_SYSROOT/usr/bin/ostree ]; then
        fatal "image sysroot ($IMAGE_SYSROOT) does not have ostree binary"
    fi

    if [ -z "$IMAGE_TMPROOT" ]; then
        IMAGE_TMPROOT=$IMAGE_SYSROOT.tmp-ostree
    fi

    if [ -z "$IMAGE_ARCH" ]; then
        $IMAGE_ARCH=$(objdump -f $IMAGE_SYSROOT/usr/bin/ostree | \
                          grep ^architecture: | \
                    sed 's/^architecture: //g;s/,.*$//g;s/.*://g')
    fi

    MACHINE=$IMAGE_ARCH
    case ${IMAGE_ARCH} in
        *x86-64*)  IMAGE_ARCH=x86_64;;
        *intel*64) IMAGE_ARCH=x86_64;;
        *x86-32*)  IMAGE_ARCH=x86_32;;
        *intel*32) IMAGE_ARCH=x86_32;;
        *x86*)     IMAGE_ARCH=x86;;
        *intel*)   IMAGE_ARCH=x86;;
        *)         IMAGE_ARCH=${_arch##*:};;
    esac

    if [ -z "$OSTREE_MODE" ]; then
        OSTREE_MODE=archive-z2
    fi

    OSTREE_BRANCH="$OSTREE_DISTRO/$IMAGE_ARCH/standard"
    OSTREE_BUILDID="test-build"
    OSTREE_SYSROOT="$OSTREE_REPO.sysroot"

    if [ -n "$GPG_ID" ]; then
        if [ -n "$GPG_HOME"; then
            GPG_SIGN="--gpg-homedir=$GPG_HOME --gpg-sign=$GPG_ID"
        else
            GPG_SIGN="--gpg-sign=$GPG_ID"
        fi
    fi
    GPG_SIGN="" # for now...
}

# Copy the image so we can adjust it for OSTree usage.
image_copy () {
    if [ ! -d "$IMAGE_SYSROOT" ]; then
        fatal "copy_image: image sysroot directory $IMAGE_SYSROOT not found"
    fi

    if [ -e "$IMAGE_TMPROOT" ]; then
        fatal "copy_image: temporary sysroot $IMAGE_TMPROOT already exists."
    fi

    message "* Copying sysroot for OSTree preparation..."

    mkdir -p $IMAGE_TMPROOT

    tar -C $IMAGE_SYSROOT -cf - . | \
            tar -C $IMAGE_TMPROOT -xf -

    chmod a+rx $IMAGE_TMPROOT
}

# Copy the kernel into the temporary sysroot.
kernel_copy () {
    local _chksum

    _chksum=$(sha256sum $IMAGE_KERNEL | cut -d ' ' -f 1)
    echo "* Kernel ($IMAGE_KERNEL) checksum: $_chksum"
    cp $IMAGE_KERNEL $IMAGE_TMPROOT/boot/vmlinuz-$_chksum
    cp $IMAGE_INITRAMFS $IMAGE_TMPROOT/boot/initramfs-$_chksum
}

# Clean up the temporary image sysroot.
image_cleanup () {
    message "* Cleaning up temporary OSTree sysroot..."

    if [ -d "$IMAGE_SYSROOT" ]; then
        rm -fr $IMAGE_SYSROOT
    fi
}

# Prepare the temporary sysroot adjusting it for OSTree usage.
image_prepare () {
    message "* Preparing temporary OSTree sysroot..."

    cd $IMAGE_TMPROOT

    # Create empty sysroot, bind-mounted to physical / by OSTree during boot.
    mkdir sysroot

    # Symlink ostree to sysroot/ostree as required by OSTree.
    ln -sf sysroot/ostree ostree

    # Move etc to usr/etc to be the 'default' configuration.
    mv etc usr/etc

    rm -fr var
    mkdir var

    rm -fr home
    ln -sf var/home home

    rm -fr mnt
    ln -sf var/mnt mnt

    rm -fr tmp
    ln -sf sysroot/tmp tmp

    cd -
}

# Initialize OSTree repository.
repo_init () {
    message "* Initializing OSTree repository $OSTREE_REPO..."

    if [ -d $OSTREE_REPO ]; then
        message "Using already existing repository..."
    else
        mkdir -p $OSTREE_REPO
        ostree --repo=$OSTREE_REPO init --mode=$OSTREE_MODE
    fi
}

# Populate OSTree repository with $IMAGE_ROOTFS.
repo_populate () {
    message "* Populating OSTree repository..."

    ostree --repo=$OSTREE_REPO commit $GPG_SIGN \
        --tree=dir=$IMAGE_TMPROOT \
        --skip-if-unchanged \
        --branch=$OSTREE_BRANCH \
        --subject="Build $OSTREE_BUILDID"
}

# Create OSTree-based sysroot.
sysroot_create () {
    message "* Initalizing sysroot ($OSTREE_SYSROOT) from $OSTREE_REPO..."

    mkdir -p $OSTREE_SYSROOT
    ostree admin --sysroot=$OSTREE_SYSROOT init-fs $OSTREE_SYSROOT
    ostree admin --sysroot=$OSTREE_SYSROOT os-init $OSTREE_DISTRO

    message "* Copying image /home ($IMAGE_SYSROOT/home) to OSTree sysroot..."
    tar -C $IMAGE_SYSROOT -cf - home | \
            tar -C $OSTREE_SYSROOT -xf -

    message "* Populating sysroot ($OSTREE_SYSROOT) from $OSTREE_REPO..."
    ostree --repo=$OSTREE_SYSROOT/ostree/repo pull-local \
        --remote=$OSTREE_DISTRO $OSTREE_REPO $OSTREE_BRANCH

    message "* Deploying into sysroot..."
    ostree admin --sysroot=$OSTREE_SYSROOT deploy \
        --os=$OSTREE_DISTRO $OSTREE_DISTRO:$OSTREE_BRANCH
}


#########################
# main script

parse_command_line $*

echo "      OSTREE_REPO: $OSTREE_REPO"
echo "      OSTREE_MODE: $OSTREE_MODE"
echo "    OSTREE_DISTRO: $OSTREE_DISTRO"
echo "         GPG_HOME: $GPG_HOME"
echo "           GPG_ID: $GPG_ID"
echo "    IMAGE_SYSROOT: $IMAGE_SYSROOT"
echo "    IMAGE_TMPROOT: $IMAGE_TMPROOT"
echo "       IMAGE_ARCH: $IMAGE_ARCH"
echo "     IMAGE_KERNEL: $IMAGE_KERNEL"
echo "  IMAGE_INITRAMFS: $IMAGE_INITRAMFS"
echo "          MACHINE: $MACHINE"

set -e
set -o pipefail

image_copy
kernel_copy
image_prepare
repo_init
repo_populate
sysroot_create
#image_cleanup

exit 0
