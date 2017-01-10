# nologin can come from two separate sources, shadow and util-linux.
# Normally these do not conflict, the one in shadow goes into /sbin,
# the one here, in util-linux, goes into /usr/sbin.
#
# With usrmerge enabled, however, /sbin is symlinked to /usr/sbin
# and these start conflicting. In that case we make util-linux get
# out of the way.
#
# Notes: I'm not sure if it is possible to compile entirely without
# shadow in which case we'd end up without a (/usr)/sbin/nologin,
#
do_install_append () {
    if [ -n "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', 'y', '', d)}" ];
    then
        rm -f ${D}${sbindir}/nologin
    fi
}


