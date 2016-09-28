include flatpak-runtime-image.bb

SUMMARY = "Flatpak SDK image for the target- and binary compatible devices."

# Pull in development tools.
IMAGE_FEATURES_append = " dev-pkgs dbg-pkgs "
IMAGE_INSTALL_append = " gcc gcc-symlinks g++ g++-symlinks"

