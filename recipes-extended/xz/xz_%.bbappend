do_install_append_class-native () {
    for _pc in ${D}${libdir}/pkgconfig/*.pc; do
        case $_pc in
            *'*.pc') rm -fr ${D}${libdir}/pkgconfig;;
            *.pc)    break;;
        esac
    done
}
