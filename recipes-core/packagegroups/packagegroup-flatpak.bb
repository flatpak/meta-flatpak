SUMMARY = "PROJECTNAME Flatpak Application Support"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    flatpak flatpak-utils flatpak-fake-runtime \
"
