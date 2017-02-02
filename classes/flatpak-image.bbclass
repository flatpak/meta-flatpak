IMAGE_FEATURES[validitems] += " \
    flatpak \
"

IMAGE_FEATURES += " \
    flatpak \
"

FEATURE_PACKAGES_flatpak = " \
    packagegroup-flatpak \
    ${@'flatpak-predefined-repos' \
         if d.getVar('FLATPAK_APP_REPOS') else ''} \
"

inherit flatpak-repo

