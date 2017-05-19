DESCRIPTION = "A package containing keys and URLs of flatpak application repositories."
HOMEPAGE = "http://127.0.0.1/"
LICENSE = "BSD-3-Clause"

LIC_FILES_CHKSUM = "file://LICENSE-BSD;md5=f9f435c1bd3a753365e799edf375fc42"

SRC_URI = " \
    git://git@github.com/klihub/flatpak-predefined-repos.git;protocol=https;branch=master \
"

SRCREV = "21becf15db4f33fbf208a880997797fea8bf1dd9"

S = "${WORKDIR}/git"

inherit autotools flatpak-variables

# For each repo named <r> we expect a <r>.url and <r>.key file (containing
# the repo URL and the repo pubic GPG key), and passwd/group entries for
# the associated users.
#
# Turn the space-separated repo name list into a comma-separated one and
# pass it to configure.
EXTRA_OECONF += " \
    --with-repos=${@','.join(d.getVar('FLATPAK_APP_REPOS', False).split())} \
"

# We can't just blindly inherit useradd. It has a parse-time check and
# will bail out if we inherit it without setting USERADD_PARAM_${PN} or
# set it to be empty... which is exactly what we end up doing when we
# don't have pre-defined repositories to put into the image.
#
# Therefore, we inherit useradd conditionally only if the set of repos
# is not empty to avoid a parse-time failure.
#
inherit ${@'useradd' if d.getVar('FLATPAK_APP_REPOS', False) else ''}

# Ask for the creation of the necessary repo users/groups (turn the
# space-separated list into a semi-colon-separated one).
USERADD_PACKAGES = "${PN}"
USERADD_PARAM_${PN} = "${@';'.join(d.getVar('FLATPAK_APP_REPOS', False).split())}"


FILES_${PN} = " \
    ${sysconfdir}/flatpak-session/* \
"

do_configure_prepend () {
    local _build _r

    _build="${@d.getVar('TOPDIR', False)}"
    FLATPAK_APP_REPOS="${@d.getVar('FLATPAK_APP_REPOS', False)}"
    if [ -z "$FLATPAK_APP_REPOS" ]; then
        return 0
    fi

    mkdir -p ${S}/repos
    for _r in $FLATPAK_APP_REPOS; do
        cp $_build/conf/$_r.url ${S}/repos
        cp $_build/conf/$_r.key ${S}/repos
    done
}

