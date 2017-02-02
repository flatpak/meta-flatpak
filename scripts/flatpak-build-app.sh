#!/bin/bash

# Print help on usage.
print_usage () {
    local _ec="${1:-1}"
    shift

    if [ -n "$*" ]; then
        echo "$*"
    fi

    echo "usage: $0 -n <name> [-s <src> -c <cmd> [other options]]"
    echo "    <name>     application id, flatpak name will be org.flatpak.<name>"
    echo "    <src>      sub-directory containing the application source"
    echo "    <cmd>      command used to start up the application"
    echo "The optional options are:"
    echo "    -S <ns>    run with a shared given namespace"
    echo "    -F <fs>    allow access to the given filesystem, which can be"
    echo "               'host', 'home', or a path"
    echo "    -R <repo>  flatpak repository to export the application to"
    echo "    -C <uri>   clone the sources from the given Git URI"
    echo "    <version>  use application version/branch, defaults to 0.0.1"
    echo ""
    echo "For example:"
    echo "    wget http://some.where.org/zsh-5.2.tar.gz"
    echo "    tar -xvzf zsh-5.2.tar.gz"
    echo "    $0 --name zsh --source zsh-5.2 --command zsh \\"
    echo "       --share network,ipc --filesystem home"

    exit $_ec
}

# Parse the command line.
parse_command_line () {
    while [ -n "$1" ]; do
        case $1 in
            --arch)
                ARCH="$2"
                shift 2
                ;;

            # options for the SDK to use
            --sdk)
                SDK_NAME="$2"
                shift 2
                ;;

            --sdk-version)
                SDK_VERSION="$2"
                shift 2
                ;;

            # options for the application to build
            --org|-o)
                APP_ORG="$2"
                shift 2
                ;;

            --name|-n)
                APP_NAME="$2"
                shift 2
                ;;

            --src|--source|-s)
                APP_SRC="$2"
                shift 2
                ;;

            --clone|-C)
                APP_URI="$2"
                shift 2
                ;;

            # options for flatpak metadata
            --app-version)
                APP_VERSION="$2"
                shift 2
                ;;

            --command|--cmd|-c)
                shift
                while [ -n "$1" -a "$1" != "--" ]; do
                    [ -n "$APP_CMD" ] && APP_CMD="$APP_CMD $1" || APP_CMD="$1"
                    shift
                done
                [ "$1" = "--" ] && shift || :
                ;;

            --share)
                APP_SHARE="$APP_SHARE --share=$2"
                shift 2
                ;;

            --filesystem|--fs)
                APP_FS="$APP_FS --filesystem=$2"
                shift 2
                ;;

            # options for the flatpak repo to export to
            --repo)
                APP_REPO="$2"
                shift 2
                ;;

            --gpg-home|--gpg-homedir)
                GPG_HOME="$2"
                shift 2
                ;;

            --gpg-key|--gpg-id)
                GPG_ID="$2"
                shift 2
                ;;

            --help|-h)
                print_usage 0
                ;;

            *)
                print_usage 1 "unknown argument $1"
                ;;
            esac
    done

    if [ -z "$APP_NAME" ]; then
        print_usage 1 "missing application name (--name <app>)"
    fi

    if [ -z "$ARCH" ]; then
        ARCH=$(uname -m)
    fi

    if [ -z "$APP_REPO" ]; then
        APP_REPO="$(pwd)/$APP_NAME.flatpak"
    fi

    if [ -z "$APP_SRC" ]; then
        APP_SRC=$APP_NAME
    fi

    if [ -z "$APP_CMD" ]; then
        APP_CMD=$APP_NAME
    fi

    if [ -z "$APP_ORG" ]; then
        APP_ORG="${SDK_NAME%.BaseSdk}"
    fi

    if [ -n "$GPG_ID" ]; then
        if [ -n "$GPG_HOME" ]; then
            GPG_SIGN="--gpg-homedir=$GPG_HOME --gpg-sign=$GPG_ID"
        else
            GPG_SIGN="--gpg-sign=$GPG_ID"
        fi
    fi

    builddir="$(pwd)/.build.$APP_NAME"
    RUNTIME_NAME="${SDK_NAME%.BaseSdk}.BasePlatform"
}

# clone application sources
clone_sources () {
    if [ -e $APP_SRC ]; then
        return 0
    fi

    if [ ! -n "$APP_URI" ]; then
        echo "error: no sources found ($APP_SRC) and no app URI given."
        exit 1
    fi

    echo "* Cloning $APP_URI to $APP_SRC..."
    git clone $APP_URI $APP_SRC
}

# Initialize the flatpak build directory.
flatpak_init () {
    echo "* Initializing flatpak build directory ($builddir) for $APP_NAME..."

    rm -fr $builddir && mkdir $builddir
    flatpak build-init $builddir \
        $APP_ORG.$APP_NAME \
        $SDK_NAME $RUNTIME_NAME \
        $APP_VERSION
}

# Configure the application for flatpak build.
flatpak_configure () {
    echo "* Configuring $APP_NAME for flatpak build..."

    cd $APP_SRC

    if [ ! -f configure ]; then
        if [ -x autogen.sh ]; then
            ./autogen.sh
        elif [ -x bootstrap ]; then
            ./bootstrap
        fi
    fi

    if [ -x configure ]; then
        flatpak build $builddir ./configure --prefix=/app
    elif [ ! -f Makefile ]; then
        echo "error: don't know how to configure this package..."
        exit 1
    fi

    cd ..
}

# Build the application for/with flatpak.
flatpak_build () {
    echo "* Building $APP_NAME for flatpak exporting..."

    cd $APP_SRC

    flatpak build $builddir make

    cd ..
}

# Install the application for/with flatpak.
flatpak_install () {
    echo "* Performing flatpak install for $APP_NAME..."

    cd $APP_SRC

    flatpak build $builddir make install

    cd ..
}

# Resolve libraries missing from the runtime image.
flatpak_resolve_libs () {
    echo "* Resolving libraries for $APP_NAME..."

    flatpak build $builddir ./scripts/resolve-libs.sh -v \
        -P runtime.libs -R / -F $builddir/files
}

# Finalize the flatpak build of the application.
flatpak_finish () {
    echo "* Finalizing flatpak build of $APP_NAME..."
    echo "*   namespaces: $APP_SHARE"
    echo "*   filesystems: $APP_FS"
    echo "*   command: $APP_CMD"

    flatpak build-finish $builddir \
        $APP_SHARE $APP_FS --command="$APP_CMD"
}

# Export the application to the given repository.
flatpak_export () {
    local _m=$builddir/metadata

#    cat >> $_m <<-EOF
#	#
#	#[Context]
#	#shared=ipc;network
#	#sockets=pulseaudio;wayland;x11
#	#devices=dri
#	#filesystems=~/dir;/absolute/path;home(full home!);host(full access!!!)
#	#
#	#[Environment]
#	#FOO=bar
#	#FOOBAR=xyzzy
#	#
#	#[Session Bus Policy]
#	#foo.bar.service=own
#	#xyzzy.frob.service=talk
#	#
#	# By default the updater will automatically install applications as
#	# as they are discovered. Similarly, by default the generated session
#	# for the repository will start all installed applications. Applications
#	# can opt out from these defaults by setting X-Install and X-Start to
#	# no or false.
#	#X-Install=yes
#	#X-Start=yes
#	#
#	# Updates can be marked as important or critical. The updater will try
#	# to fetch, apply and activate such updates as soon as possible.
#	#X-Urgency=important
#EOF

    [ -n "$EDITOR" ] && $EDITOR $_m || vi $_m

    flatpak build-export $GPG_SIGN $APP_REPO $builddir
}


#########################
# main script
SDK_NAME="iot.refkit.BaseSdk"
SDK_ARCH="x86_64"
SDK_VERSION="latest-build"

APP_NAME=""
APP_VERSION="latest-build"
APP_REPO=""

GPG_ID="iot-ref-kit@key"
GPG_HOME=""
GPG_SIGN=""

set -e

parse_command_line $*

clone_sources
flatpak_init
flatpak_configure
flatpak_build
flatpak_install
#flatpak_resolve_libs
flatpak_finish
flatpak_export

echo ""
echo "$APP_NAME exported to $APP_REPO $APP_ORG.$APP_NAME version $APP_VERSION."

exit 0
