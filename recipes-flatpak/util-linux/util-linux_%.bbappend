do_install_append_class-target () {
    if [ -n "${@bb.utils.contains('DISTRO_FEATURES', 'usrmerge', 'y', '', d)}" ];
    then
        rm -f ${D}${sbindir}/nologin
    fi
}
