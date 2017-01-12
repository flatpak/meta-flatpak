#!/bin/bash

# Print help on usage.
print_usage () {
    echo "usage: $0 [options]"
    echo ""
    echo "Take a runtime or SDK image sysroot directory and commit it into a"
    echo "flatpak/OSTree repository. If the repository does not exist by"
    echo "default it is created in archive-z2 mode. Such a repository is"
    echo "suitable to be exported over HTTP/HTTPS for flatpak clients to fetch"
    echo "fetch runtime/SDK images and flatpak application from."
    echo "archive-z2 format, suitable to be exported over HTTP for clients to"
    echo "fetch data from."
    echo ""
    echo "The other possible options are:"
    echo "  --repo-path <repo>   path to flatpak repository to populate"
    echo "  --repo-mode <type>   repository mode [archive-z2]"
    echo "  --repo-org <org>     how to name runtime and branches [iot.refkit]"
    echo "  --repo-export <exp>  export the image also to archive-z2 <exp>"
    echo "  --gpg-home <dir>     GPG home directory for keyring"
    echo "  --gpg-id <id>        GPG key id to use for signing"
    echo "  --image-dir <dir>    image directory to populate repository with"
    echo "  --image-type <type>  image type (runtime or sdk)"
    echo "  --image-arch <arch>  image architecture (x86, x86-64, ...)"
    echo "  --image-version <v>  image version/branch [0.0.1]"
    echo "  --image-libs <path>  image library list, if any, to generate"
    echo "  --tmp-dir <path>     directory for temporary files (/tmp)"
    echo "  --help               print this help and exit"
}

# Parse the command line.
parse_command_line () {
    while [ -n "$1" ]; do
        case $1 in
            --repo-path|--repo|-r)
                REPO_PATH=$2
                shift 2
                ;;
            --repo-mode)
                REPO_MODE=$2
                shift 2
                ;;
            --repo-org)
                REPO_ORG=$2
                shift 2
                ;;
            --repo-export)
                REPO_EXPORT=$2
                shift 2
                ;;

            --gpg-home|--gpg-homedir|-G)
                GPG_HOME=$2
                shift 2
                ;;
            --gpg-id|-I)
                GPG_ID=$2
                shift 2
                ;;

            --image-dir|-D)
                IMG_SYSROOT=$2
                shift 2
                ;;
            --image-arch|--arch|-A)
                IMG_ARCH=$2
                shift 2
                ;;
            --image-version|--version|-V)
                IMG_VERSION=$2
                shift 2
                ;;
            --image-buildid|--buildid|-B)
                IMG_BUILDID=$2
                shift 2
                ;;
            --image-type|--type|-T)
                IMG_TYPE=$2
                shift 2
                ;;
            --image-libs|--libs)
                IMG_LIBS=$2
                shift 2
                ;;

            --tmp-dir|-t)
                IMG_TMPDIR=$2
                shift 2
                ;;

            --help|-h)
                print_usage
                exit 0
                ;;

            *)
                echo "Unknown command line option/argument $1."
                print_usage
                exit 1
                ;;
        esac
    done

    REPO_ARCH=${IMG_ARCH#qemu}
    REPO_ARCH=${REPO_ARCH//-/_}
    echo "REPO_ARCH: $REPO_ARCH"

    case $IMG_ARCH in
        qemux86-64) REPO_ARCH=x86_64;    QEMU_ARCH=qemux86-64;;
        qemux86)    REPO_ARCH=x86;       QEMU_ARCH=qemux86;;
        x86_64)     REPO_ARCH=x86_64;    QEMU_ARCH=qemux86-64;;
        x86)        REPO_ARCH=x86;       QEMU_ARCH=qemux86;;
        *)          REPO_ARCH=$IMG_ARCH; QEMU_ARCH=$IMG_ARCH;;
    esac

    if [ -z "$IMG_TYPE" ]; then
        echo "Image type not given, assuming 'sdk'..."
        IMG_TYPE=sdk
    fi

    case $IMG_TYPE in
        runtime)
            REPO_BRANCH=runtime/$REPO_ORG.BasePlatform/$REPO_ARCH/$IMG_VERSION
            ;;
        sdk)
            REPO_BRANCH=runtime/$REPO_ORG.BaseSdk/$REPO_ARCH/$IMG_VERSION
            ;;
        *)
            echo "Invalid image type: $IMG_TYPE";
            exit 1
            ;;
    esac

    VERSION_BRANCH=version/$IMG_TYPE/$REPO_ARCH/$IMG_VERSION

    if [ -n "$IMG_BUILDID" ]; then
        BUILD_BRANCH=build/$IMG_TYPE/$REPO_ARCH/$IMG_BUILDID
    else
        BUILD_BRANCH=""
    fi

    if [ -z "$IMG_SYSROOT" ]; then
        echo "Image sysroot directory not given."
        exit 1
    fi

    SYSROOT=$IMG_TMPDIR/$IMG_TYPE.sysroot
    REPO_METADATA=$SYSROOT/metadata
}

# Create image metadata file for the repository.
metadata_generate () {
    echo "* Generating $IMG_TYPE image metadata ($REPO_METADATA)..."

    (echo "[Runtime]"
     if [ "$IMG_TYPE" != "sdk" ]; then
         echo "name=$REPO_ORG.BasePlatform"
     else
         echo "name=$REPO_ORG.BaseSdk"
     fi
     echo "runtime=$REPO_ORG.BasePlatform/$REPO_ARCH/$REPO_VERSION"
     echo "sdk=$REPO_ORG.BaseSdk/$REPO_ARCH/$REPO_VERSION" ) > $REPO_METADATA
}

# Populate temporary sysroot with flatpak-translated path names.
sysroot_populate () {
    echo "* Creating flatpak-relocated sysroot ($SYSROOT) from $IMG_SYSROOT..."
    mkdir -p $SYSROOT
    bsdtar -C $IMG_SYSROOT -cf - ./usr ./etc | \
        bsdtar -C $SYSROOT \
            -s ":^./usr:./files:S" \
            -s ":^./etc:./files/etc:S" \
            -xvf -
}

# Clean up temporary sysroot.
sysroot_cleanup () {
    echo "* Cleaning up $SYSROOT..."
    rm -rf $SYSROOT
}

# Initialize flatpak/OSTree repository, if necessary.
repo_init () {
    if [ ! -d $REPO_PATH ]; then
        echo "* Creating ${REPO_MODE:-archive-z2} repository $REPO_PATH..."
        mkdir -p $REPO_PATH
        ostree --repo=$REPO_PATH init --mode=${REPO_MODE:-archive-z2}
    else
        echo "* Using existing repository $REPO_PATH..."
        [ -n "$REPO_MODE" ] && echo "WARNING: mode $REPO_MODE ignored" || :
    fi

    if [ -z "$REPO_EXPORT" ]; then
        return 0
    fi

    if [ ! -d $REPO_EXPORT ]; then
        echo "* Creating export repository $REPO_EXPORT..."
        mkdir -p $REPO_EXPORT
        ostree --repo=$REPO_EXPORT init --mode=archive-z2
    else
        echo "* Using existing export repository $REPO_EXPORT..."
    fi
}

# Populate the repository.
repo_populate () {
    # OSTree can't handle files with no read permission
    echo "* Fixup permissions for OSTree..."
    find $SYSROOT -type f -exec chmod u+r {} \;

    echo "* Populating repository with $IMG_TYPE image (branch $REPO_BRANCH)..."
    ostree --repo=$REPO_PATH commit \
           --gpg-homedir=$GPG_HOME --gpg-sign=$GPG_ID \
           --owner-uid=0 --owner-gid=0 --no-xattrs \
           -s "$IMG_TYPE $IMG_VERSION" \
           -b "Commit of $IMG_TARBALL into the repository." \
           --branch=$REPO_BRANCH $SYSROOT

    echo "* Creating version branch $VERSION_BRANCH..."
    ostree --repo=$REPO_PATH commit --branch=$VERSION_BRANCH \
           --tree=ref=$REPO_BRANCH

    if [ -n "$BUILD_BRANCH" ]; then
        echo "* Creating build branch $BUILD_BRANCH"
        ostree --repo=$REPO_PATH commit --branch=$BUILD_BRANCH \
               --tree=ref=$REPO_BRANCH
    fi
}

# Update repository summary.
repo_update_summary () {
    echo "* Updating repository summary..."
    ostree --repo=$REPO_PATH summary -u \
           --gpg-homedir=$GPG_HOME --gpg-sign=$GPG_ID
}

# Mirror the branch we created to our export repository.
repo_export () {
    if [ -n "$REPO_EXPORT" ]; then
        echo "* Mirroring $REPO_PATH to export repository $REPO_EXPORT..."
        ostree --repo=$REPO_EXPORT pull-local $REPO_PATH
        ostree --repo=$REPO_EXPORT summary -u \
           --gpg-homedir=$GPG_HOME --gpg-sign=$GPG_ID
        repo_apache_config
    else
        echo "* No export repo given, not exporting (in archive-z2 format)..."
    fi
}

# Generate and HTTP configuration fragment for the exported repository.
repo_apache_config () {
    local _repo_path

    cd $REPO_EXPORT && _repo_path=$(pwd) && cd -

    echo "* Generating apache2 config fragment for $REPO_EXPORT..."
    (echo "Alias \"/flatpak/\" \"$_repo_path/\""
     echo ""
     echo "<Directory $_repo_path>"
     echo "Options Indexes FollowSymLinks"
     echo "Require all granted"
     echo "</Directory>") > $REPO_EXPORT.http.conf
}

# Generate list of libraries provided by the image.
generate_lib_list () {
    [ -z "$IMG_LIBS" ] && return 0

    echo "* Generating list of provided libraries..."
    (cd $IMG_SYSROOT; find . -type f -name lib\*.so.\*) | \
        sed 's#^\./#/#g' > $IMG_LIBS
}


#########################
# main script

REPO_PATH=flatpak.repo
REPO_ORG=iot.refkit
REPO_MODE=""
REPO_EXPORT=""

GPG_HOME=.gpg.flatpak
GPG_ID=iot-refkit@key

IMG_TMPDIR=/tmp
IMG_ARCH=x86_64
IMG_VERSION=0.0.1
IMG_BUILDID=""
IMG_SYSROOT=""
IMG_TYPE=""
IMG_LIBS=""

parse_command_line $*

echo "image root: $IMG_SYSROOT"
echo "      type: $IMG_TYPE"
echo "      arch: $IMG_ARCH"
echo " repo arch: $REPO_ARCH"
echo "   version: $IMG_VERSION"
echo "  build-id: $IMG_BUILDID"
echo " qemu arch: $QEMU_ARCH"

set -e

repo_init
sysroot_populate
metadata_generate
repo_populate
repo_update_summary
repo_export
#generate_lib_list
sysroot_cleanup
