FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# GpgME gpg backends
GPGME_BACKENDS ?= "gnupg"

RDEPENDS_${PN} += "${GPGME_BACKENDS}"

BBCLASSEXTEND = "native"
