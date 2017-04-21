SUMMARY = "PROJECTNAME OSTree Supporting Packages"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    ostree \
    refkit-ostree \
    efivar \
    efibootmgr \
    ca-certificates \
"
