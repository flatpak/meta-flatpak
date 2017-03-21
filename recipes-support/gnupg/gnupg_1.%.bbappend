FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# libmpi needs gnu89 extern inline semantics.
# AFAIK, the in-recipe kludge of 'CFLAGS += "-fgnu89-inline"' is
# not the proper way of doing it, since CFLAGS is not an official
# bitbake variable. And indeed it does not seem to work as expected.
# We should fix the oe-core recipe and submit it upstream.
#
# Meanwhile... we live with this.
do_configure_prepend () {
    CFLAGS="$CFLAGS -fgnu89-inline"
}

# The original recipe declares a runtime dependency for the splitted
# out gpv with a
#    RDEPENDS_${PN} = "gpgv"
#
# Now that we BBCLASSEXTEND/inherit native.bbclass, this would break
# native builds with an unresolvable gpgv-native. So to patch things
# up we need to replace the original dependency with a class-target one.
RDEPENDS_${PN}_remove = "gpgv"
RDEPENDS_${PN}_class-target = "gpgv"

BBCLASSEXTEND = "native nativesdk"

