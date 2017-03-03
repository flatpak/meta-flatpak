FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

DEPENDS += "ca-certificates"
RDEPENDS_${PN} += "ca-certificates"


BBCLASSEXTEND = "native"
