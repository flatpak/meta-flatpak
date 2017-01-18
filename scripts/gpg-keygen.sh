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
    echo "    -o <output>  file(s) to store keys in (<output>.{cfg,sec,pub})"
    echo "    -T <type>    type of key to generate (DSA)"
    echo "    -L <len>     length of key to generate (2048)"
    echo "    -t <subtype> type of subkey to generate (ELG-E)"
    echo "    -l <sublen>  length of subkey to generate (2048)"
    echo "    -n <name>    real name associated with the generated key"
    echo "    -m <mail>    e-mail address associated with the genrated key"
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
            --name|-n)
                GPG_NAME="$2"
                shift 2;
                ;;
            --id|--email|-e|--mail|-m)
                GPG_ID="$2"
                shift 2
                ;;
            --output|-o|--base)
                GPG_BASE="$2"
                shift 2
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
        GPG_ID="$GPG_BASE@key"
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
GPG_NAME="IoT RefKit Signing Key"
GPG_BASE="iot-refkit"
GPG_HOME=".gpg.flatpak"
GPG2_IMPORT=""

set -e

parse_command_line $*

gpg1_mkconfig
gpg1_genkeys
gpg2_import
