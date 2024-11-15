#!/usr/bin/env bash

tmpf=$(mktemp)

function add_build_cdef {
    if [ "$*" != "" ] ; then
        echo "#define BUILD_PLATFORM_$@" >> ${tmpf}
    fi
}

echo "#define SRC_GIT_REMOTE \"$(git remote -v | grep fetch | sed -e s@^.*https://@@ -e s/\ .*$//)\"" > ${tmpf}
echo "#define SRC_GIT_BRANCH \"$(git branch --show-current)\"" >> ${tmpf}
echo "#define SRC_GIT_HEAD_REV \"$(git rev-parse HEAD)\"" >> ${tmpf}

add_build_cdef $(cat /etc/os-release | grep -w PRETTY_NAME | sed -e "s/=/ /")
add_build_cdef $(cat /etc/os-release | grep -w CPE_NAME | sed -e "s/=/ /")
add_build_cdef "ARCH" \"$(uname -m)\"

if ! cmp ${tmpf} build_info.h >& /dev/null ; then
    cp ${tmpf} build_info.h
    touch build_info.h
fi
