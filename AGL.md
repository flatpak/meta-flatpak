# Flatpak with AGL

This branch updates this meta-layer to work with a modern Poky and openembedded,
with the aim of working correctly with AGL. As with the original layer, this
gives the capability to both use flatpak inside an image (e.g. to run
applications from flathub) or to produce a custom flatpak image for use as a
base for applications. I'll deal with each of these in turn.

## Set up

First, one needs to gather the AGL sources. This can be done by following the
instructions upstream. With that out of the way, we need to add this meta-layer
and its dependencies. Navigate to the `external/` directory and clone this
repository. You'll need to add this to your bitbake layers by using:

```bash
bitbake-layers add-layer meta-openembedded/meta-oe
bitbake-layers add-layer meta-openembedded/meta-gnome
bitbake-layers add-layer meta-openembedded/meta-filesystems
bitbake-layers add-layer meta-openembedded/meta-networking
bitbake-layers add-layer meta-flatpak
```

Some of these may already be included in the default layer configuration.

## Flatpak in AGL

This section handles the inclusion of flatpak in an AGL bootable image. To do
this, one needs to modify the `local.conf` file used by bitbake to configure
builds. The inclusion of the following should be enough:

```
# Include flatpak in the image.
IMAGE_INSTALL_append = " flatpak"

# We need more space for apps and stuff
# This adds 8GB, which may be excessive for general use
IMAGE_ROOTFS_EXTRA_SPACE_append = " + 8000000"

# Make sure we get the necessary dependencies
DISTRO_FEATURES_append = " wayland seccomp"

# Include configuration from this repo
include conf/distro/include/flatpak-applications.inc
```

One can then `bitbake agl-demo-platform` to produce the image as normal. Running
this should include a working flatpak. To test that it works, I suggest grabbing
a terminal interface (via SSH or serial on the VM) and performing the following:

```bash
flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --system flathub org.vim.Vim
flatpak run org.vim.Vim
```

As you may expect, this will download and run Vim from flathub. The choice of
Vim is entirely due to it being a TUI application as opposed to something
requiring a graphical stack, where things are a little more fraught.

With out-of-the-box AGL, applications which support Wayland should work out of
the box. I've personally attested that various GTK+ applications work just by
installing and running them. Qt applications seem to be missing an environment
variable being set, and need to be run like so:

```
flatpak run --env=QT_QPA_PLATFORM=wayland org.kde.Dolphin
```

This has worked with every Qt application I've tried.

Unfortunately, the stock platform image doesn't include XWayland, and so X11
applications don't seem to work. Despite my best efforts, I haven't managed to
integrate XWayland in such a way that X11 applications work reliably with the
agl-compositor. Sadly this means that I haven't managed to run Minecraft in the
image yet.

Other applications have more bespoke errors, for example SuperTuxKart seems to
struggle with audio as well as video. I manage to get it running using Weston
compiled with XWayland support as the compositor, but I couldn't get it happy
with agl-compositor.

## AGL in Flatpak

This section handles the production of a flatpak image based on AGL from
bitbake. The implementation of this is the `.bbclass` files and related scripts
in this repository. To build, one first needs to ensure `usrmerge` is enabled in
the image - flatpak expects everything to live in `/usr`.

One can then `bitbake core-image-flatpak-runtime` or `bitbake
core-image-flatpak-sdk` depending on the desired image. This will output
wholesale flatpak repositories containing the image. Trying to build these with
the GPG signing stuff enabled causes everything to break for me, so I've added a
convenient flag to disable it.

Once you successfully wrangle a flatpak repository out, you should be able to
add the repository to your local flatpak installation by:

```
flatpak remote-add --if-not-exists --user --no-gpg-verify core-image-flatpak-runtime.flatpak agl
```

The `--no-gpg-verify` flag is only required if you, like me, disabled the GPG
signing. We can now verify the existence of the image in the repository by:

```
flatpak remote-ls --user agl
```

This should list something like
`runtime/iot.poky_agl.BasePlatform/x86_64/{ref}`. There may be several entries
with different values of `ref`. 

Installing and running the runtime can be achieved now by:

```
flatpak install --user agl iot.poky_agl.BasePlatform//{ref}
flatpak run iot.poky_agl.BasePlatform
```

It should be possible to build apps on top of this using flatpak-builder, but I
haven't tried that yet.

