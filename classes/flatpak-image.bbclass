IMAGE_FEATURES[validitems] += " \
    flatpak \
"

FEATURE_PACKAGES_flatpak = " \
    packagegroup-flatpak \
    ca-certificates \
    ${@'flatpak-predefined-repos' \
         if d.getVar('FLATPAK_APP_REPOS') else ''} \
"

inherit flatpak-repo
