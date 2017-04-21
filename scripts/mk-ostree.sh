#!/bin/sh

#############################################
# global variables
DISTRO=''                                   # distro name
ARCH=''                                     # target/image architecture
MACHINE=''                                  # machine name
PRISTINE_SYSROOT=''                         # input, sysroot in original layout
OSTREE_SYSROOT=''                           # output, ostree-shuffled sysroot
SYSROOT_REPO=''                             # output, primary (bare) repository
EXPORT_REPO=''                              # output, archive-z2 repository
ACTIONS=''                                  # requested actions to perform
VERBOSE=''                                  # extended verbosity
KEEP_TMP=''                                 # keep temporary artefacts
OVERWRITE=''                                # overwrite existing artefacts
TMPDIR=''                                   # temporary work directory
COMMIT_SUBJECT=""                           # repo commit message

# Print help on usage.
print_usage () {
    echo "usage: $0 [options] [actions]"
    echo ""
    echo "Create an OSTree-enabled version of an image rootfs, also creating a"
    echo "per-image OSTree bare-user repository. Optionally export the content"
    echo "of this repository into HTTP-exportable archive-z2 OSTree repository"
    echo "which clients can use to pull the image in as an OSTree upgrade."
    echo ""
    echo "The possible options are:"
    echo "  --distro <name>       distribution name to use within OSTree"
    echo "  --arch <arch>         architecture the image is compiled for"
    echo "  --src <dir>           pristine rootfs to use as input"
    echo "  --dst <dir>           OSTree rootfs directory to produce"
    echo "  --repo <repo>         bare-user repository to genrtate"
    echo "  --export <repo>       archive-z2 repository to export to"
    echo "  --tmpdir <dir>        temporary directory to use"
    echo "  --subject <msg>       ostree commit/subject message"
    echo "  --gpg-home <dir>      GPG home directory for signing"
    echo "  --gpg-id <id>         GPG key ID to sign repository commit"
    echo "  --verbose             increase logging verbosity"
    echo "  --keep-tmp            keep produced temporary artefacts"
    echo "  --overwrite           overwrite existing artefacts"
    echo "  --machine <machine>   Yocto ${MACHINE} to derive architecture from"
    echo "  --help                print (this) help on usage"
    echo ""
    echo "The possible actions are:"
    echo "  prepare-sysroot       prepare OSTree-enabled sysroot and bare repo"
    echo "  export-repo           export to archive-z2 repo"
}

# Print a message.
msg () {
    echo "$*"
}

# Print a debug message.
debug () {
    if [ -z "$VERBOSE" ]; then
        return
    fi

    if [ "$VERBOSE" -gt 1 ]; then
        echo "D: $*"
    fi
}

# Print an info message.
info () {
    if [ -n "$VERBOSE" ]; then
        echo "$*"
    fi
}

# Print a non-fatal error message.
error () {
    echo "error: $*"
}

# Print a fatal error message.
fatal () {
    echo "fatal error: $*"
    exit 1
}

# Detect target architecture.
detect_architecture () {
    local _arch _bin _i _tmp

    if [ -z "$PRISTINE_SYSROOT" -a -z "$OSTREE_SYSROOT" ]; then
        fatal "Can't detect target architecture without a sysroot."
    fi

     _bin=''
     if [ -e $PRISTINE_SYSROOT/boot/EFI/BOOT/boot*.efi ]; then
        for _i in $PRISTINE_SYSROOT/boot/EFI/BOOT/boot*.efi; do
            _bin=$_i
            break
        done
    else
        for _i in $OSTREE_SYSROOT/boot/EFI/BOOT/boot*.efi; do
            _bin=$_i
            break
        done
    fi

    if [ -z "$_bin" ]; then
        fatal "Can't detect target architecture without UEFI combo app."
    fi

    mkdir -p $TMPDIR
    _tmp=$TMPDIR/kernel
    objcopy --dump-section .linux=$_tmp
    _arch=$(objdump --file-headers $_tmp | grep ^architecture: | \
                sed 's/^architecture: //;s/, flags.*$//g')
    rm -fr $TMPDIR

    if [ -z "$_arch" ]; then
        fatal "Failed to detect target architecture."
    fi

    case $_arch in
        *x86-64*)   ARCH=x86_64;;
        *intel*64*) ARCH=x86_64;;
        *x86-32*)   ARCH=x86_32;;
        *intel*32*) ARCH=x86_32;;
        *x86*)      ARCH=x86;;
        *intel*)    ARCH=x86;;
        *)          ARCH=$_arch;; # Well, maybe...
    esac
}

# Check if $ACTIONS contains a particular one.
has_action () {
    if [ "${ACTIONS/${1}/}" != "$ACTIONS" ]; then
        return 0
    else
        return 1
    fi
}

# Parse the command line options.
parse_cmdline () {
    msg "parsing command line \"$*\"..."
    while [ $# -gt 0 ]; do
        debug "processing argument $1..."
        if [ "${1#-}" != "$1" ]; then
            case $1 in
                --distro|-D)
                    DISTRO="$2"
                    shift 2
                    ;;
                --machine|-m)
                    MACHINE="$2"
                    shift 2
                    ;;
                --arch|-A)
                    ARCH="$2"
                    shift 2
                    ;;
                --src|-s|--source|--sysroot|--pristine-sysroot)
                    PRISTINE_SYSROOT="$2"
                    shift 2
                    ;;
                --dst|-d|--destination|--ostree-sysroot)
                    OSTREE_SYSROOT="$2"
                    shift 2
                    ;;
                --repo|-r|--sysroot-repo|--primary-repo)
                    SYSROOT_REPO="$2"
                    shift 2
                    ;;
                --subject|--commit-subject)
                    COMMIT_SUBJECT="$2"
                    shift 2
                    ;;
                --export|-e|--export-repo)
                    EXPORT_REPO="$2"
                    shift 2
                    ;;
                --tmpdir)
                    TMPDIR="$2"
                    shift 2
                    ;;
                --gpg-home)
                    GPG_HOME="$2"
                    shift 2
                    ;;
                --gpg-id)
                    GPG_ID="$2"
                    shift 2
                    ;;
                --verbose|-v)
                    [ -z "$VERBOSE" ] && VERBOSE=1 || let VERBOSE=$VERBOSE+1
                    shift
                    ;;
                --keep|-k|--keep-tmp)
                    KEEP_TMP=1
                    shift
                    ;;
                --overwrite|-O)
                    OVERWRITE=1
                    shift
                    ;;
                --help|-h)
                    print_usage
                    exit 0
                    ;;
                *)
                    echo "Unknown command line option $1."
                    print_usage
                    exit 1
                    ;;
            esac
        else
            case $1 in
                prepare|prepare-sysroot)
                    ACTIONS="$ACTIONS prepare-sysroot"
                    shift
                    ;;
                export-repo)
                    ACTIONS="$ACTIONS export-repo"
                    shift
                    ;;
                *)
                    error "Unknown action $1"
                    print_usage
                    exit 1
                    ;;
            esac
        fi
    done

    if [ -z "$DISTRO" ]; then
        DISTRO="refkit"
    fi

    if [ -z "$TMPDIR" ]; then
        TMPDIR="/tmp/ostree-repo.$$"
    fi

    if [ -z "$ACTIONS" ]; then
        ACTIONS="prepare-sysroot"
    fi

    if [ -n "$GPG_ID" ]; then
        if [ -n "$GPG_HOME" ]; then
            GPG_SIGN="--gpg-homedir=$GPG_HOME"
        fi
        GPG_SIGN="$GPG_SIGN --gpg-sign=$GPG_ID"
    fi

    if [ -z "$ARCH" ]; then
        detect_architecture
    fi

    if has_action export-repo; then
        if [ -z "$SYSROOT_REPO" ]; then
            fatal "Need primary repository path for exporting."
        fi

        if [ -z "$EXPORT_REPO" ]; then
            EXPORT_REPO="${SYSROOT_REPO%.ostree*}.ostree-http"
        fi

        #if [ ! -d $SYSROOT_REPO ]; then
        #    ACTIONS="prepare-sysroot $ACTIONS"
        #fi
    fi

    if has_action prepare-sysroot; then
        if [ -z "$PRISTINE_SYSROOT" ]; then
            fatal "Need pristine-sysroot for sysroot population."
        fi

        if [ -z "$OSTREE_SYSROOT" ]; then
            OSTREE_SYSROOT="$PRISTINE_SYSROOT.ostree"
        fi
    fi

    case $ARCH in
        x86_64)   UEFIAPP=bootx64.efi;;
        x86)      UEFIAPP=bootia32.efi;;
        *arm*64*) UEFIAPP=bootaa64.efi;;
        *arm*)    UEFIAPP=bootarm.efi;;
        *)        UEFIAPP=boot$ARCH.efi;; # Well, not...
    esac

    OSTREE_BRANCH=$DISTRO/$ARCH/standard

    if [ -z "$COMMIT_SUBJECT" ]; then
        COMMIT_SUBJECT="Build of $DISTRO @ $(date +'%Y-%m-%d %H:%m:%S')"
    fi

    msg "DISTRO: $DISTRO"
    msg "MACHINE: $MACHINE"
    msg "ARCH: $ARCH"
    msg "PRISTINE_SYSROOT: $PRISTINE_SYSROOT"
    msg "OSTREE_SYSROOT: $OSTREE_SYSROOT"
    msg "SYSROOT_REPO: $SYSROOT_REPO"
    msg "EXPORT_REPO: $EXPORT_REPO"
    msg "COMMIT_SUBJECT: $COMMIT_SUBJECT"
    msg "ACTIONS: $ACTIONS"
    msg "GPG_ID: $GPG_ID"
    msg "GPG_HOME: $GPG_HOME"
    msg "KEEP_TMP: $KEEP_TMP"
    msg "OVERWRITE: $OVERWRITE"
}

# Seed the OSTree sysroot with the pristine one.
copy_sysroot () {
    info "Copying pristine sysroot to OSTree sysroot..."

    mkdir -p $OSTREE_SYSROOT
    tar -C $PRISTINE_SYSROOT -cf - . | \
        tar -C $OSTREE_SYSROOT -xf -
    chmod a+rx $OSTREE_SYSROOT
}

# Copy and checksum kernel, initramfs, and the UEFI app in place for OSTree.
copy_kernel () {
    local _chksum _kernel _initrd _uefiapp

    msg "Copying and checksumming UEFI combo app(s) into OSTree sysroot..."
    mkdir -p $OSTREE_SYSROOT/usr/lib/ostree-boot
    _uefiapp=$OSTREE_SYSROOT/usr/lib/ostree-boot/$UEFIAPP
    cp $PRISTINE_SYSROOT/boot/EFI/BOOT/$UEFIAPP $_uefiapp.ext
    cp $PRISTINE_SYSROOT/boot/EFI_internal_storage/BOOT/$UEFIAPP $_uefiapp.int
    _chksum=$(/usr/bin/sha256sum $_uefiapp.ext | cut -d ' ' -f 1)
    mv $_uefiapp.ext $_uefiapp.ext-$_chksum
    _chksum=$(/usr/bin/sha256sum $_uefiapp.int | cut -d ' ' -f 1)
    mv $_uefiapp.int $_uefiapp.int-$_chksum

    msg "Extracting and checksumming kernel, initramfs for ostree..."
    _kernel=$OSTREE_SYSROOT/usr/lib/ostree-boot/vmlinuz
    _initrd=$OSTREE_SYSROOT/usr/lib/ostree-boot/initramfs
    objcopy --dump-section .linux=$_kernel --dump-section .initrd=$_initrd \
        $PRISTINE_SYSROOT/boot/EFI/BOOT/$UEFIAPP

    _chksum=$(/usr/bin/sha256sum $_kernel | cut -d ' ' -f 1)
    mv $_kernel $_kernel-$_chksum
    mv $_initrd $_initrd-$_chksum
}

# Mangle sysroot into an OSTree-compatible layout.
ostreeify_sysroot () {
    local _l _t _pwd

    msg "* Shuffling sysroot to OSTree-compatible layout..."

    _pwd=$PWD
    cd $OSTREE_SYSROOT

    # The OSTree deployment model requires the following directories
    # and symlinks in place:
    #
    #     /sysroot: the real physical rootfs bind-mounted here
    #     /sysroot/ostree: ostree repo and deployments ('checkouts')
    #     /ostree: symlinked to /sysroot/ostree for consistent access
    #
    # Additionally the deployment model suggest setting up deployment
    # root symlinks for the following:
    #
    #     /home -> /var/home (further linked -> /sysroot/home)
    #     /opt -> /var/opt
    #     /srv -> /var/srv
    #     /root -> /var/roothome
    #     /usr/local -> /var/local
    #     /mnt -> /var/mnt
    #     /tmp -> /sysroot/tmp
    #
    # We slightly diverge from the suggestions (for a reason) and
    # actually set up the following deployment symlinks:
    #
    #     /home -> /sysroot/home
    #     /mnt -> /var/mnt
    #     /tmp -> /sysroot/tmp
    #
    # Additionally,
    #     /etc is moved to /usr/etc as the default config

    mkdir -p sysroot
    ln -sf sysroot/ostree ostree

    rm -fr boot var home
    mkdir boot var home

    rm -fr mnt tmp
    ln -sf var/mnt mnt
    ln -sf sysroot/tmp tmp

    mv etc usr/etc

    cd usr/etc
    for _l in $(find . -type l); do
        _t=$(readlink $_l)
        case $_t in
            ../../*) ;;
            ../*)    ln -sf ../$_t $_l;;
            *)       ;;
        esac
    done
    cd ../..

    cd $_pwd
}

# Prepare a rootfs for committing into an OSTree repository.
prepare_sysroot () {
    if [ -d $OSTREE_SYSROOT ]; then
        if [ -z "$OVERWRITE" ]; then
            msg "$OSTREE_SYSROOT already exists, using it..."
            return 0
        else
            msg "$OSTREE_SYSROOT already exists, nuking it..."
            rm -fr $OSTREE_SYSROOT
        fi
    fi

    msg "Preparing OSTree sysroot $OSTREE_SYSROOT..."
    copy_sysroot
    copy_kernel
    ostreeify_sysroot
}

# Finalize OSTree sysroot by checking it out from the repository.
checkout_sysroot () {
    msg "Checking out OSTree sysroot from primary repository..."

    rm -fr $OSTREE_SYSROOT

    info "Initializing OSTree deployment sysroot..."
    mkdir -p $OSTREE_SYSROOT
    ostree admin --sysroot=$OSTREE_SYSROOT init-fs $OSTREE_SYSROOT
    ostree admin --sysroot=$OSTREE_SYSROOT os-init $DISTRO

    info "Replicating primary OSTree repository..."
    ostree --repo=$OSTREE_SYSROOT/ostree/repo pull-local \
        --remote=$DISTRO $SYSROOT_REPO $OSTREE_BRANCH

    info "Deploying rootfs from OSTree sysroot repository..."
    ostree admin --sysroot=$OSTREE_SYSROOT deploy \
        --os=$DISTRO $DISTRO:$OSTREE_BRANCH

    info "Copying pristine sysroot /boot to OSTree sysroot..."
    tar -C $PRISTINE_SYSROOT -cf - boot | \
        tar -C $OSTREE_SYSROOT -xf -

    info "Copying pristine sysroot /home to OSTree sysroot..."
    tar -C $PRISTINE_SYSROOT -cf - home | \
        tar -C $OSTREE_SYSROOT -xf -
}


# Populate primary OSTree repository (bare-user mode) with the given sysroot.
populate_repo () {
    msg "Populating OSTree primary repository..."

    rm -fr $SYSROOT_REPO
    mkdir -p $SYSROOT_REPO
    ostree --repo=$SYSROOT_REPO init --mode=bare-user

    ostree --repo=$SYSROOT_REPO commit \
        $GPG_SIGN \
        --tree=dir=$OSTREE_SYSROOT \
        --branch=$OSTREE_BRANCH \
        --subject="$COMMIT_SUBJECT"

    ostree --repo=$SYSROOT_REPO summary -u
}

# Export data from a primary OSTree repository to the given (archive-z2) one.
export_repo () {
    msg "Exporting sysroot to OSTree repository..."

    if [ ! -d $EXPORT_REPO ]; then
        info "Initializing repository $EXPORT_REPO for exporting..."
        mkdir -p $EXPORT_REPO
        ostree --repo=$EXPORT_REPO init --mode=archive-z2
    fi

    ostree --repo=$EXPORT_REPO pull-local \
        --remote=$DISTRO $SYSROOT_REPO $OSTREE_BRANCH

    ostree --repo=$EXPORT_REPO commit $GPG_SIGN \
        --branch=$OSTREE_BRANCH --tree=ref=$DISTRO:$OSTREE_BRANCH

    ostree --repo=$EXPORT_REPO summary $GPG_SIGN -u
}


#############################################
# main script

set -e

parse_cmdline $*

if has_action 'prepare-sysroot'; then
    prepare_sysroot
    populate_repo
    checkout_sysroot
fi

if has_action 'export-repo'; then
    export_repo
fi
