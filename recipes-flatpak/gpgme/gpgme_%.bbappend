require ../common/extend-native.inc

# GpgME gpg backends
GPGME_BACKENDS ?= "gnupg"

RDEPENDS_${PN} += "${GPGME_BACKENDS}"
