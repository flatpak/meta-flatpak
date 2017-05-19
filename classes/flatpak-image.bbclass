IMAGE_FEATURES[validitems] += " \
    flatpak \
    tools-sdk dev-pkgs tools-debug tools-profile \
"

FEATURE_PACKAGES_flatpak = " \
    packagegroup-flatpak \
    ${@'flatpak-predefined-repos' \
         if d.getVar('FLATPAK_APP_REPOS', False) else ''} \
"

inherit flatpak-repo

#
# Define our image variants for flatpak support.
#
# - runtime variant 'flatpak':
#     Adds the necessary runtime bits for flatpak support. Using this
#     image on a device makes it possible to pull in, update and run
#     applications from flatpak repositories.
#
# - SDK variant 'flatpaksdk':
#     Adds the necessary compile-time bits for compiling applications
#     and publishing them as flatpaks in flatpak repositories. During
#     image creation a flatpak repository will be populated with the
#     contents of this image from where it can then be flatpak-installed
#     for developing flatpaks for the 'flatpak' image variant.
#

# 'flatpak-runtime' variant (runtime image for a device)
IMAGE_VARIANT[flatpak-runtime] = "flatpak"

# 'flatpak-sdk' variant (SDK image for a development host)
IMAGE_VARIANT[flatpak-sdk] = "flatpak tools-develop tools-debug dev-pkgs"

BBCLASSEXTEND = "imagevariant:flatpak-runtime imagevariant:flatpak-sdk"
