include flatpak-runtime-image.bb

SUMMARY = "Flatpak SDK image for the target- and binary compatible devices."

# Pull in development tools.
IMAGE_FEATURES_append = " dev-pkgs dbg-pkgs tools-sdk"
IMAGE_INSTALL_append = " git"

