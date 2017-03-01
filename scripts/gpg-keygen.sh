#!/bin/bash

# Print help on usage.
print_usage () {
    echo "usage: $0 -c config | -o output [ options ]"
    echo ""
    echo "Generate GPG signing keyring for our flatpak/OSTree repository and"
    echo "export the generated public and secret keys from the keyring."
    echo ""
    echo "The possible options are:"
    echo "    -c <config>  use provided GPG config file, ignore other options."
    echo "    -m <mail>    e-mail address for the key (iot-ref-kit@key)"
    echo "    -o <output>  file(s) to store keys in (${mail%@*}.{cfg,sec,pub})"
    echo "    -n <name>    real name associated with the generated key"
    echo "    -T <type>    type of key to generate (DSA)"
    echo "    -L <len>     length of key to generate (2048)"
    echo "    -t <subtype> type of subkey to generate (ELG-E)"
    echo "    -l <sublen>  length of subkey to generate (2048)"
    echo "    -H <home>    GPG home directory for the keyring."
    echo "    -2           import keys to GPG2 keyring as well"
    echo "    -h           show this help"
}

# Parse the command line.
parse_command_line () {
    while [ -n "$1" ]; do
        case $1 in
            --type|-T)
                GPG_TYPE="$2"
                shift 2
                ;;
            --length|-L)
                GPG_LENGTH="$2"
                shift 2
                ;;
            --subkey-type|-t)
                GPG_SUBTYPE="$2"
                shift 2
                ;;
            --subkey-length|-l)
                GPG_SUBLENGTH="$2"
                shift 2
                ;;
            --id|--email|-e|--mail|-m)
                GPG_ID="$2"
                shift 2
                ;;
            --output|-o|--base)
                GPG_BASE="$2"
                shift 2
                ;;
            --name|-n)
                GPG_NAME="$2"
                shift 2;
                ;;
            --config|-c)
                GPG_CONFIG="$2"
                shift 2
                ;;
            --home|-H)
                GPG_HOME="$2"
                shift 2
                ;;
            --gpg2|-2)
                GPG2_IMPORT="yes"
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;

            *)
                print_usage
                exit 1
                ;;
        esac
    done

    if [ -z "$GPG_ID" ]; then
        GPG_ID="iot-ref-kit@key"
    else
        if [ "${GPG_ID##*@}" = "$GPG_ID" ]; then
            GPG_ID="$GPG_ID@key"
        fi
    fi

    if [ -z "$GPG_BASE" ]; then
        GPG_BASE="${GPG_ID%%@*}"
    fi

    if [ -z "$GPG_NAME" ]; then
        GPG_NAME="Signing Key for ${GPG_BASE%%@*}"
    fi

    echo "* GPG key parameters:"
    echo "      home: ${GPG_HOME:-default gpg home}"
    echo "    key ID: $GPG_ID"
    echo "      name: $GPG_NAME"
    echo "     files: $GPG_BASE.{cfg,pub,sec}"
}

# Check if the requested keys already exist.
gpg1_chkkeys ()
{
    if [ -e $GPG_BASE.pub -a -e $GPG_BASE.sec ]; then
        echo "* GPG keys $GPG_BASE.{pub,sec} exist, nothing to do..."
        exit 0
    fi
}

# Generate GPG --batch mode key generation configuration file (unless given).
gpg1_mkconfig () {
    if [ -n "$GPG_CONFIG" ]; then
        if [ ! -f "$GPG_CONFIG" ]; then
            echo "Missing GPG config file $GPG_CONFIG."
            exit 1
        fi
        echo "* Using provided GPG config file: $GPG_CONFIG"
    else
        GPG_CONFIG="$GPG_BASE.cfg"

        echo "* Generating GPG config file $GPG_CONFIG..."

        (echo "%echo Generating repository signing GPG keys..."
	 echo "Key-Type: $GPG_TYPE"
	 echo "Key-Length: $GPG_LENGTH"
	 echo "Subkey-Type: $GPG_SUBTYPE"
	 echo "Subkey-Length: $GPG_SUBLENGTH"
	 echo "Name-Real: $GPG_NAME"
	 echo "Name-Email: $GPG_ID"
	 echo "Expire-Date: 0"
	 echo "%pubring $GPG_BASE.pub"
	 echo "%secring $GPG_BASE.sec"
	 echo "%commit"
	 echo "%echo done") > $GPG_CONFIG
    fi
}

# Generate GPG1 keys and keyring.
gpg1_genkeys () {
    echo "* Generating GPG1 keys and keyring..."

    mkdir -p $GPG_HOME
    chmod og-rwx $GPG_HOME

    gpg --homedir=$GPG_HOME --batch --gen-key $GPG_CONFIG
    gpg --homedir=$GPG_HOME --import $GPG_BASE.sec
    gpg --homedir=$GPG_HOME --import $GPG_BASE.pub
}

# Mark all keys trusted in our keyring.
gpg1_trustkeys () {
    local _trustdb=gpg.trustdb _fp

    #
    # This is a bit iffy... we misuse a supposedly private
    # GPG API (the trust DB format).
    #

    echo "* Marking keys trusted in keyring..."

    gpg --homedir=$GPG_HOME --export-ownertrust > $_trustdb

    # Note: we might end up with duplicates but that's ok...
    for _fp in $(gpg --homedir=$GPG_HOME --fingerprint | \
                     grep " fingerprint = " | sed 's/^.* = //g;s/ //g'); do
        echo $_fp:6: >> $_trustdb
    done

    gpg --homedir=$GPG_HOME --import-ownertrust < $_trustdb
}

# Import keys to GPG2 keyring.
gpg2_import () {
    if [ "$GPG2_IMPORT" = "yes" ]; then
        echo "* Importing keys to GPG2 keyring..."
        gpg --homedir=$GPG_HOME --export-secret-keys | gpg2 --import
    else
        echo "* GPG2 import not requested, skipping..."
    fi
}


#########################
# main script

GPG_TYPE="DSA"
GPG_LENGTH="2048"
GPG_SUBTYPE="ELG-E"
GPG_SUBLENGTH="2048"
GPG_HOME=".gpg.flatpak"
GPG_BASE=""
GPG_ID=""
GPG_NAME=""
GPG2_IMPORT=""

set -e

parse_command_line $*

gpg1_chkkeys
gpg1_mkconfig
gpg1_genkeys
gpg1_trustkeys
gpg2_import
