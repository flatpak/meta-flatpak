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
    echo "  --repo-path <repo>    path to flatpak repository to populate"
    echo "  --repo-mode <type>    repository mode [archive-z2]"
    echo "  --repo-org <org>      how to name runtime and branches [iot.refkit]"
    echo "  --repo-export <exp>   export the image also to archive-z2 <exp>"
    echo "  --gpg-home <dir>      GPG home directory for keyring"
    echo "  --gpg-id <id>         GPG key id to use for signing"
    echo "  --image-dir <dir>     image directory to populate repository with"
    echo "  --image-base <name>   image basename"
    echo "  --image-type <type>   image type (runtime or sdk)"
    echo "  --image-arch <arch>   image architecture (x86, x86-64, ...)"
    echo "  --image-version <v>   image version/branch [0.0.1]"
    echo "  --distro-version <v>  distro version/branch"
    echo "  --rolling-version <v> rolling version/branch [current]"
    echo "  --image-libs <path>   image library list, if any, to generate"
    echo "  --tmp-dir <path>      directory for temporary files (/tmp)"
    echo "  --help                print this help and exit"
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
            --distro-version)
                DISTRO_VERSION=$2
                shift 2
                ;;
            --image-version|--version|-V)
                IMG_VERSION=$2
                shift 2
                ;;
            --rolling-version)
                ROLLING_VERSION=$2
                shift 2
                ;;
            --image-base|--base)
                IMG_BASE=$2
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

            -*)
                echo "Unknown command line option/argument $1."
                print_usage
                exit 1
                ;;

             *)
                actions="$actions $1"
                shift
                ;;
        esac
    done

    if [ -z "$actions" ]; then
        if [ -n "$REPO_EXPORT" ]; then
            actions="populate export"
        else
            actions="populate"
        fi
    fi

    if [ -z "$ROLLING_VERSION$DISTRO_VERSION$IMG_VERSION" ]; then
        ROLLING_VERSION="current"
    fi

    case $IMG_ARCH in
        qemux86-64) REPO_ARCH=x86_64;;
        intel*64)   REPO_ARCH=x86_64;;
        *x86-64)    REPO_ARCH=x86_64;;
        qemux86-32) REPO_ARCH=x86_32;;
        intel*32)   REPO_ARCH=x86_32;;
        *x86-32)    REPO_ARCH=x86_32;;
        qemux86)    REPO_ARCH=x86;;
        intel*)     REPO_ARCH=x86;;
        *x86)       REPO_ARCH=x86;;
        *)          REPO_ARCH="${IMG_ARCH#qemu}";;
    esac

    if [ -z "$IMG_TYPE" ]; then
        echo "Image type not given, assuming 'sdk'..."
        IMG_TYPE=sdk
    fi

    case $IMG_TYPE in
        runtime) BASE_TYPE=BasePlatform;;
        sdk)     BASE_TYPE=BaseSdk;;
        none)    BASE_TYPE=BasePlatform;;
        *)
            echo "Invalid image type: $IMG_TYPE";
            exit 1
            ;;
    esac

    if [ -z "$IMG_BASE" ]; then
        IMG_BASE="image-unknown"
    fi

    BRANCH_BASE="runtime/$REPO_ORG.$BASE_TYPE/$REPO_ARCH"

    if [ -n "$IMG_VERSION" ]; then
        IMAGE_BRANCH="$BRANCH_BASE/image-$IMG_VERSION"
        BASE_BRANCH="$IMAGE_BRANCH"
    fi

    if [ -n "$DISTRO_VERSION" ]; then
        DISTRO_BRANCH="$BRANCH_BASE/distro-$DISTRO_VERSION"
        if [ -z "$BASE_BRANCH" ]; then
            BASE_BRANCH="$DISTRO_BRANCH"
        fi
    fi

    if [ -n "$ROLLING_VERSION" ]; then
        ROLLING_BRANCH="$BRANCH_BASE/$ROLLING_VERSION"
        if [ -z "$BASE_BRANCH" ]; then
            BASE_BRANCH="$ROLLING_BRANCH"
        fi
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
        case "$actions" in
            *populate*) ;;
            *) echo "error: no repo ($REPO_PATH) to export"
               exit 1
               ;;
        esac

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
    flatpak build-export --files=files "$REPO_PATH" "$SYSROOT" stable

    echo "* Populating repository with $IMG_TYPE image (branch $BASE_BRANCH)..."
    flatpak build-commit-from --src-ref="${BRANCH_BASE}/stable" $REPO_PATH $BASE_BRANCH

    if [ -n "$IMAGE_BRANCH" -a "$IMAGE_BRANCH" != "$BASE_BRANCH" ]; then
        echo "* Creating image branch $IMAGE_BRANCH..."
        flatpak build-commit-from --src-ref="${BRANCH_BASE}/stable" $REPO_PATH $IMAGE_BRANCH
    fi

    if [ -n "$DISTRO_BRANCH" -a "$DISTRO_BRANCH" != "$BASE_BRANCH" ]; then
        echo "* Creating image branch $DISTRO_BRANCH..."
        flatpak build-commit-from --src-ref="${BRANCH_BASE}/stable" $REPO_PATH $DISTRO_BRANCH
    fi

    if [ -n "$ROLLING_BRANCH" -a "$ROLLING_BRANCH" != "$BASE_BRANCH" ]; then
        echo "* Creating rolling branch $ROLLING_BRANCH..."
        flatpak build-commit-from --src-ref="${BRANCH_BASE}/stable" $REPO_PATH $ROLLING_BRANCH
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
    local _repo_alias

    cd $REPO_EXPORT && _repo_path=$(pwd) && cd -
    _repo_alias="/flatpak/${IMG_BASE%-flatpak-*}/$IMG_TYPE/"

    echo "* Generating apache2 config fragment for $REPO_EXPORT..."
    (echo "Alias \"$_repo_alias\" \"$_repo_path/\""
     echo ""
     echo "<Directory $_repo_path>"
     echo "    Options Indexes FollowSymLinks"
     echo "    Require all granted"
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
IMG_SYSROOT=""
IMG_TYPE=""
IMG_LIBS=""

actions=""
parse_command_line $*

echo "image root: $IMG_SYSROOT"
echo "      type: $IMG_TYPE"
echo "      arch: $IMG_ARCH"
echo " repo arch: $REPO_ARCH"
echo "  rolling version: ${ROLLING_VERSION:-none}"
echo "   distro version: ${DISTRO_VERSION:-none}"
echo "    image version: ${IMG_VERSION:-none}"
echo "   version: $IMG_VERSION"

set -e


repo_init

if [ "${actions//populate/}" != "$actions" ]; then
    sysroot_populate
    metadata_generate
    repo_populate
    repo_update_summary
    #generate_lib_list
    sysroot_cleanup

    actions="${actions//populate/}"
fi

if [ "${actions//export/}" != "$actions" ]; then
    repo_export
    actions="${actions//export/}"
fi

if [ -n "${actions// /}" ]; then
    echo "error: unknown actions \"$actions\""
    exit 1
fi
