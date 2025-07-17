#!/bin/bash
set -eo pipefail
echoerr () { echo "${@}" >&2; }; die () { local r="${?}"; echoerr "${@}"; exit "${r}"; }
trap 'echoerr -e "${0}: \e[0;91mExit with Error Code ${?} at Line ${LINENO}\e[0m"' ERR

# dest
dest='/opt/debian-bin'
# dir
workdir='/workdir'
self="${workdir}/${0##*/}"
cd /result
mkdir setup

# https://packages.debian.org/index
install_dest () { sed 's|\${dest}|'"${dest}"'|g' | install "${@}"; }
for i in "${workdir}"/*.sh; do [[ "${i}" == "${self}" ]] || . "${i}"; done
# setup head
for i in setup/*.sh; do
cat - "${i}" >"${i}".tmp <<'EOF'
#!/bin/bash
set -eo pipefail
echoerr () { echo "${@}" >&2; }; die () { local r="${?}"; echoerr "${@}"; exit "${r}"; }
trap 'echoerr -e "${0}: \e[0;91mExit with Error Code ${?} at Line ${LINENO}\e[0m"' ERR

EOF
mv "${i}".tmp "${i}"
done
# check
: "${pkg:?}" "${bin:?}" "${etc:?}"

# install
apt-get update
apt-get upgrade -y
apt-get install -y patchelf "${pkg[@]}"

# etc
cp -vLt ./ -r --parents -n "${etc[@]}"
# bin
mkdir bin
cp -vLt bin/ "${bin[@]}"
# ld
cp -vLt ./ "$( patchelf --print-interpreter /bin/bash )"
ld="${_##*/}"
# lib
mkdir lib
ldd bin/* | grep -oP '=>\s\K\S+' | sort | uniq | xargs -d '\n' cp -vLt lib/
chmod -v 644 lib/*

# patchelf
patchelf --set-rpath '$ORIGIN/lib' --set-interpreter "${dest}/${ld}" bin/*
patchelf --set-rpath '$ORIGIN' lib/*
# move out bin
mv -vt ./ bin/*; rm -r bin

# done
true
