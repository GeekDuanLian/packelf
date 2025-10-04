#!/bin/bash
set -eo pipefail
echoerr () { echo "${@}" >&2; }; die () { local r="${?}"; echoerr "${@}"; exit "${r}"; }
trap 'echoerr -e "${0}: \e[0;91mExit with Error Code ${?} at Line ${LINENO}\e[0m"' ERR

# dir
workdir='/workdir'
cd /result
# env
export DEBIAN_FRONTEND='noninteractive'

# https://packages.debian.org/index
# postinst: /var/lib/dpkg/info/
# rpm: rpm -q --scripts
install_dest () {
    local dst="${1:?}" mode="${2:-644}"
    [[ "${dst}" == /* ]] && dst="${dst:1}" # dst start with / but we need include it
    install -vD"m${mode}" /dev/stdin "${dst}"
}
script_header="$( head -4 "${0}" )"
_install_setup () { { echo "${script_header}"; echo; cat; } | install_dest setup/"${1:?}.sh" 755; }

# work
for i in "${workdir}"/*.sh; do
    # mkdir
    : "${i##*/}"; name="${_%.sh}"
    mkdir -v "${name}"
    cd "${name}"
    # source
    install_setup () { _install_setup "${name}"; }
    declare bin ldd; unset pkg bin etc ldd;
    . "${i}"
    # etc
    [[ "${etc}" ]] && cp -vLt ./ --parents -rn "${etc[@]}"
    # bin
    mkdir bin
    cp -vLt "${_}" "${bin[@]}"
    # ld
    cp -vLt ./ "$( patchelf --print-interpreter /bin/bash )"
    ld="${_##*/}"
    # lib
    mkdir -p lib
    ldd bin/* "${ldd[@]}" | grep -oP '=>\s\K\S+' | sort | uniq | xargs -d '\n' cp -vLt "${_}"
    chmod -v 644 "${_}"/*
    # patchelf
    patchelf --set-rpath '$ORIGIN/lib' --set-interpreter "${dest:?}/${ld}" bin/*
    patchelf --set-rpath '$ORIGIN' lib/*
    # move out bin
    mv -vt ./ bin/*; rm -r bin
    # done
    cd ..
done

# done
true
