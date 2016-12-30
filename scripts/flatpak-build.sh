#!/bin/bash

# Print help on usage.
print_usage () {
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
}

# Parse the command line.
parse_command_line () {
    while [ -n "$1" ]; do
        case $1 in
            --name|-n)
                FLATPAK_APP="$2"
                shift 2
                ;;
            --src|--source|-s)
                FLATPAK_SRC="$2"
                shift 2
                ;;
            --command|-c)
                shift
                while [ -n "$1" ]; do
                    [ -n "$FLATPAK_CMD" ] && FLATPAK_CMD="$FLATPAK_CMD $1" || \
                            FLATPAK_CMD="$1"
                    shift
                done
                ;;
            --version|-v)
                FLATPAK_VER="$2"
                shift 2
                ;;
            --share|-S)
                FLATPAK_SHARE="$FLATPAK_SHARE --share=$2"
                shift 2
                ;;
            --filesystem|--fs|-F)
                FLATPAK_FS="$FLATPAK_FS --filesystem=$2"
                shift 2
                ;;
            --repo|-R)
                FLATPAK_REPO="$2"
                shift 2
                ;;
            --clone|-C)
                FLATPAK_CLONE="$2"
                shift 2
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;

            *)
                print_usage "unknown argument $1"
                exit 1
                ;;
            esac
    done

    if [ -z "$FLATPAK_APP" ]; then
        print_usage "missing application name (--name <app>)"
        exit 1
    fi

    if [ -z "$FLATPAK_SRC" ]; then
        FLATPAK_SRC=$FLATPAK_APP
    fi

    if [ -z "$FLATPAK_CMD" ]; then
        FLATPAK_CMD=$FLATPAK_APP
    fi

    builddir=".$FLATPAK_APP.builddir"
}

# Initialize the flatpak build directory.
flatpak_init () {
    echo "* Initializing flatpak build directory..."

    rm -fr $builddir && mkdir $builddir
    flatpak build-init $builddir \
        org.flatpak.$FLATPAK_APP \
        org.yocto.BaseSdk org.yocto.BasePlatform \
        $FLATPAK_VER
}

# Configure the application for flatpak build.
flatpak_configure () {
    echo "* Configuring flatpak build..."

    cd $FLATPAK_SRC

    if [ ! -f configure ]; then
        if [ -x autogen.sh ]; then
            ./autogen.sh
        elif [ -x bootstrap ]; then
            ./bootstrap
        fi
    fi

    if [ -x configure ]; then
        flatpak build ../$builddir ./configure --prefix=/app
    elif [ ! -f Makefile ]; then
        echo "Don't know how to configure this package..."
        exit 1
    fi

    cd ..
}

# Build the application for/with flatpak.
flatpak_build () {
    echo "* Performing flatpak build..."

    cd $FLATPAK_SRC

    flatpak build ../$builddir make

    cd ..
}

# Install the application for/with flatpak.
flatpak_install () {
    echo "* Performing flatpak install..."

    cd $FLATPAK_SRC

    flatpak build ../$builddir make install

    cd ..
}

# Resolve libraries missing from the runtime image.
flatpak_resolve_libs () {
    echo "* Resolving libraries for flatpak app..."

    flatpak build $builddir ./scripts/resolve-libs.sh -v \
        -P runtime.libs -R / -F $builddir/files
}

# Finalize the flatpak build of the application.
flatpak_finish () {
    echo "* Finalizing flatpak build..."
    echo "* share: $FLATPAK_SHARE"
    echo "* filesystems: $FLATPAK_FS"
    echo "* command: $FLATPAK_CMD"

    flatpak build-finish $builddir \
        $FLATPAK_SHARE $FLATPAK_FS \
        --command="$FLATPAK_CMD"
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


    flatpak build-export $FLATPAK_SIGN $FLATPAK_REPO $builddir
}

# Clone the app sources from the given repository.
clone_sources () {
    if [ ! -e $FLATPAK_SRC ]; then
        echo "* Cloning $FLATPAK_CLONE into $FLATPAK_SRC..."
        git clone $FLATPAK_CLONE $FLATPAK_SRC
    elif [ -n "$FLATPAK_CLONE" ]; then
        echo "* $FLATPAK_SRC already exists, *not* cloning $FLATPAK_CLONE..."
    fi
}


#########################
# main script
FLATPAK_REPO="flatpak.repo"
FLATPAK_VER="0.0.1"
FLATPAK_SIGN="--gpg-homedir=$(pwd)/.gpg.flatpak --gpg-sign=repo-signing@key"
FLATPAK_CMD=""

set -e

parse_command_line $*

clone_sources
flatpak_init
flatpak_configure
flatpak_build
flatpak_install
flatpak_resolve_libs
flatpak_finish
flatpak_export

echo ""
echo "$FLATPAK_APP exported to the repository as org.flatpak.$FLATPAK_APP."

exit 0

#rm -fr $builddir && mkdir $builddir
#flatpak build-init $builddir org.flatpak.$name \
#    org.yocto.BaseSdk org.yocto.BasePlatform $version
#
#cd $dir
#flatpak build ../$builddir ./configure --prefix=/app
#flatpak build ../$builddir make
#flatpak build ../$builddir make install
#cd ..
#
#flatpak build $builddir ./resolve-libs.sh -v -P runtime.libs \
#                                             -R / -F $builddir/files
#
#flatpak build-finish $builddir \
#    --share=$SHARED --filesystem=$FILESYSTEMS --command=$command
#flatpak build-export flatpak.repo $builddir
#

