#!/bin/bash

#
# Flatpak SDK images usually contain extra libraries, pulled in
# by the toolchain or other utilities, which are not present in
# the runtime image. Components that optionally can use these
# libraries pick them up when flatpak-built and eventually fail
# to run against the runtime images... unless the extra libraries
# are packaged together with the components.
#
# This script takes a list of libraries provided by the runtime
# image, finds the used ones missing from the image, and copies
# them to the collection of files provided by the component.
#
# usage: resolve-libs.sh --provided <file> --root <dir> --files <dir> [-v]
#


declare -A provided
declare -A available
declare -A libraries
verbose=0
files=""
binaries=""

# Print a debug message (iff verbosity >= 2).
debug () {
    local _arg

    [ -z "$verbose" -o "$verbose" -lt 2 ] && return 0

    echo "D: $*"
}

# Print a message (iff verbosity >= 1).
msg () {
    local _arg

    [ -z "$verbose" -o "$verbose" -lt 1 ] && return 0

    echo "$*"
}

# Print an error message and bail out with an exit code indicating failure.
fatal () {
    local _arg

    echo "fatal error: $*" 1>&2

    exit 1
}

# Read the list of libraries provided by the runtime image from $1.
read_provided_libs () {
    local _libs _lib _l

    _libs=$(cat $1 | tr -s '\t ' ' ')

    if [ $? != 0 ]; then
        fatal "failed to read available libraries from $1"
    fi

    for _lib in $_libs; do
        _l="${_lib##*/}"
        debug "    $_l provided as $_lib"
        provided["$_l"]="$_lib"
        libraries["$_l"]="provided"
    done
}

# Check if a library is provided by the runtime image.
is_provided () {
    local _lib="${1##*/}"

    [ -n "${provided[$_lib]}" ] && return 0 || return 1
}

# Discover the available libraries in the subtree $1.
find_available_libs () {
    local _libs _lib _l

    _libs=""

    if [ -e $1/lib ]; then
        _libs+=$(find $1/lib/ -name lib\*.so.\* | tr -s '\t ' ' ')
    fi

    if [ -e $1/usr/lib ]; then
        _libs+=$(find $1/usr/lib/ -name lib\*.so.\* | tr -s '\t ' ' ')
    fi

    if [ $? != 0 ]; then
        fatal "failed to discover libraries available under $1"
    fi

    for _lib in $_libs; do
        _l="${_lib##*/}"
        debug "    $_l available as $_lib"
        available["$_l"]="$_lib"
    done
}

# Check if a library is part of the package.
is_package_lib () {
    local _lib="${1##*/}"

    debug  "    testing $files/lib/$_lib..."

    [ -e $files/lib/$_lib ] && return 0 || return 1
}

# Check if a library is available.
is_available () {
    local _lib="${1##*/}"

    [ -n "${available[$_lib]}" ] && return 0 || return 1
}

# Check if a library has already been resolved.
is_resolved () {
    local _lib="${1##*/}"

    [ -n "${libraries[$_lib]}" ] && return 0 || return 1
}

# Copy a library into an application-specific location.
copy_lib () {
    local _lib="${1##*/}" _to="${2:-$files/lib}"

    msg "        -> copying $_lib into application"
    mkdir -p $_to
    cp $1 $_to/$_lib.suppressed
    libraries[$_lib]="copied"
}

# Do a final renaming pass over the copied libraries.
unsupress_libs () {
    local _lib _path="${1:-$files/lib}"

    for _lib in $_path/*.suppressed; do
        mv $_lib ${_lib%.suppressed}
    done
}


# Copy any library not provided by the runtime image together with the app.
resolve_libs () {
    local _libs _lib _l _path _status

    file $1 | grep -q ' ELF ' || {
        debug "    not an ELF binary, skipping"
        return 0
    }

    msg "Processing $1..."

#
#   eu-readelf produces slightly different output:
#
#   _libs=$(eu-readelf -d $1 | grep ' NEEDED ' | grep -i 'shared library:' |
#                  sed 's/^.*library: //g' | tr -d '[] ' | sort -u)

    _libs=$(readelf -d $1 | grep '\(NEEDED\)' | grep -i 'shared library:' |
                   sed 's/^.*library: //g' | tr -d '[] ' | sort -u)

    if [ $? != 0 ]; then
        fatal "failed to read dynamic section from $1"
    fi

    for _lib in $_libs; do
        _l="${_lib##*/}"
        _path="${available[$_l]}"
        _status="${libraries[$_l]}"

        msg "    -> needs $_lib ($_path, ${_status:-needs copying})"

        if is_package_lib $_lib; then
            msg "        -> is a package-local library."
            continue
        fi

        if ! is_available $_lib; then
            fatal "Library $_lib is unavailable."
        fi

        is_resolved $_l && continue

        copy_lib $_path $files/lib

        resolve_libs $_path
    done
}

# Print help on usage.
print_usage () {
    echo "usage: $0 -P <libs> -R <root> [-F <files> | <binaries> [-v]"
    echo ""
    echo "  -P <libs-file>  list of libraries provided by the runtime image"
    echo "  -R <root>       root directory to search for libraries"
    echo "  -F <file>       flatpak app directory to search for ELF binaries"
    echo "  <binaries>      explicit list of binaries if -F is omitted"
    echo "  -v              increase verbosity"
}

# Parse the command line.
parse_command_line () {
    while [ -n "$1" ]; do
        case $1 in
            --root|-R)
              msg "Using root directory: $2"
              find_available_libs $2
              shift 2
              ;;
            --provided|-P)
              msg "Reading runtime-provided libraries from $2..."
              read_provided_libs $2
              shift 2
              ;;
            --files|-F)
              debug "Application files directory: $2"
              files=$2
              shift 2
              ;;
            --verbose|-v)
              verbose=$(($verbose+1))
              shift
              ;;
            --debug|-d)
              verbose=2
              shift
              ;;
            -*)
              fatal "invalid option $1"
              ;;
            *)
              binaries="$binaries $1"
              shift
              ;;
        esac
    done

    [ -z "$files" -a -z "$binaries" ] && {
        print_usage
        fatal "neither files nor binaries given"
    }
}

#########################
# main script

# Parse the command line.
parse_command_line $*

# Try to read default provided file if nothing else was given.
if [ -z "${provided[*]}" -a -e runtime.libs ]; then
    read_provided_libs runtime.libs
fi

# Dump given configuration.
msg "Staging/files directory: $files"

if [ -n "$verbose" -a "$verbose" -gt 1 ]; then
    msg "Libraries provided by the runtime image:"
    for lib in "${!provided[@]}"; do
        msg "    $lib (${provided[$lib]})"
    done

    msg "Libraries available in SDK image:"
    for lib in "${!available[@]}"; do
        msg "    $lib (${available[$lib]})"
    done
fi

# Go through given or found binaries, resolving library dependencies.
if [ -n "$binaries" ]; then
    for bin in $binaries; do
        resolve_libs $bin
    done
else
    for bin in $(find $files -type f); do
        resolve_libs $bin
    done
fi

# Do a final sweep over copied libraries, renaming them.
unsupress_libs $files/lib

# Dump reolution result.
if [ -n "$verbose" -a "$verbose" -gt 1 ]; then
    msg "Resolution:"
    for lib in "${!libraries[@]}"; do
        msg "    $lib (${libraries[$lib]})"
    done
fi

exit 0
