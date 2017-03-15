IMAGE_FEATURES[validitems] += " \
    ostree \
"

FEATURE_PACKAGES_ostree = " \
    packagegroup-ostree \
"

inherit ostree-repo

#
# Define our image variants for OSTree support.
#
# - ostree variant:
#     Adds the necessary runtime bits for OSTree support. Using this
#     image on a device makes it possible to pull in updates to the
#     base distro using OSTree. Additionally, during bitbake images
#     will be exported to an OSTree repository for consumption by
#     devices running an ostree image variant.
#

# 'ostree' variant (image with OSTree update support)
IMAGE_VARIANT[ostree] = "ostree"

BBCLASSEXTEND = "imagevariant:ostree"

