#!/usr/bin/env bash
# Common utilities for plot_openssl*.sh .
set -e
# set -x

### Params ###
# shellcheck disable=SC2034  # used in plot_openssl*.sh
VER=1.0.0
GRA_DIR="graphs"
UNAME_S="$(uname -s)"

if [ "${UNAME_S}" == "Darwin" ] ; then
    SO=dylib
    # shellcheck disable=SC2034  # used in other scripts
    DOT_LOCAL_LIB=lib
else
    SO=so
    # shellcheck disable=SC2034  # used in other scripts
    DOT_LOCAL_LIB=lib64
fi


##
# @brief        Path check
# @param[in]    ${ALLOWED_DIR}
# @param[in]    path
# @param[out]   exit 2 if given path is not allowed
check_path (){
    local real_path touched
    # TODO: test realpath and then determin if it requires the given path and file.
    # NOTE: some `realpath` command fails with "No such file or directory" for non-existant 
    if [ ! -e "$2" ] && [ "${UNAME_S}" == "Darwin" ] ; then
        touch "$2"
        touched=1
    fi
    real_path=$(realpath "$2")
    # NOTE: some `realpath` command fails with "No such file or directory" for non-existant 
    [ "${touched}" == "1" ] && rm -f "$2"
    if [[ ${real_path} != $1* ]]; then
        echo
        echo "Error: '$2' is not under the allowed dir!"
        echo
        exit 2
    fi     
}


##
# @brief        Get an array of algorithms supported by OQS
# @param[in]    "$@" : algorithm types, "kem", "signature", or both, i.e. "kem" "signature".
#               global OPENSSL : openssl command
# @param[out]   global
#                 ARR_OQS_SIG : if $algorithm types == "signature"
#                 ARR_OQS_KEM : if $algorithm types == "kem"
get_arr_oqs () {
    local arr_tmp algorithm_type
    for algorithm_type in "$@"; do
        # TODO: improve
        # IFS=" " read -r -a arr_tmp <<< "$(${OPENSSL} list -"${algorithm_type}"-algorithms -provider oqsprovider 2>/dev/null | awk '/^[^_]+ @ oqsprovider$/ {printf "%s ",$1}')"
        IFS=" " read -r -a arr_tmp <<< "$(${OPENSSL} list -"${algorithm_type}"-algorithms -provider oqsprovider 2>/dev/null | awk '/^[^_]+ @ oqsprovider$/ {print $1}' | sort -V | awk '{printf "%s ",$1}')"
        # shellcheck disable=SC2034  # used in other scripts
        case "${algorithm_type}" in
            "signature") ARR_OQS_SIG=("${arr_tmp[@]}");;
            "kem")       ARR_OQS_KEM=("${arr_tmp[@]}");;
            *) echo "Warning: '${algorithm_type}' is ignored for the get_arr_oqs()'s arguments!";;
        esac
    done
    # echo "${ARR_OQS_KEM[*]}"
    # echo "${ARR_OQS_SIG[*]}"
}


##
# @brief        Set LIBOQS_VER and so on using ${OPENSSL} command.
# @param[in]    global OPENSSL : openssl command
# @param[in]    global OPENSSL_MODULES (set in build_oqsprovider())
# @param[out]   global variables:
#                   OPENSSL_VER_ALL
#                   OPENSSL_PROVIDER
#                   LIBOQS_VER
liboqs_ver_from_command () {
    local tmp
    OPENSSL_VER_ALL="$(${OPENSSL} version -a)"
    # OPENSSL_VER="$(${OPENSSL} version)"
    # OPENSSL_VER="$(echo "${OPENSSL_VER_ALL}" | awk 'NR==1 {print $1 $2}')"
    # "OpenSSL 3.3.1", "LibreSSL 2.8.3" and so on
    # openssl_ver_nospace="$(echo "${OPENSSL_VER}" | awk '{printf "%s%s", $1,$2}')"
    # OPENSSL_VER_NOSPACE="$(echo "${OPENSSL_VER_ALL}" | awk 'NR==1 {printf "%s%s", $1,$2}')"
    # "OpenSSL3.3.1", "LibreSSL2.8.3" and so on
    unset LIBOQS_VER OPENSSL_PROVIDER
    if [[ "${OPENSSL_VER_ALL}" == *"MODULESDIR"* ]]; then
        OPENSSL_PROVIDER="$(${OPENSSL} list -providers 2>/dev/null)"
        if [[ "${OPENSSL_PROVIDER}" == *"oqsprovider"* ]]; then
            # TODO: find a more simple way to identify real LIBOQS_VER
            #       whereas plot_openssl_in_path() cannot use LIBOQS_BRANCH
            if [ -n "${OPENSSL_MODULES}" ]; then
                tmp="$(strings "${OPENSSL_MODULES}/oqsprovider.$SO" | awk '/based on liboqs/')"
            else
                # use MODULESDIR in ${OPENSSL_VER_ALL}
                # tmp="$(strings "$(echo "${OPENSSL_VER_ALL}" | awk '/MODULESDIR:/ {printf "%s",$2}' | sed -e 's/"//g')/oqsprovider.$SO" | awk '/based on liboqs/')"
                tmp="$(strings "$(echo "${OPENSSL_VER_ALL}" | awk '/MODULESDIR:/ {printf "%s",substr($2,2,length($2)-2)}')/oqsprovider.$SO" | awk '/based on liboqs/')"
            fi
            # tmp="OQS Provider v.0.6.0 (0ec51ec) based on liboqs v.0.10.1"
            LIBOQS_VER=${tmp##*liboqs v.}
            export LIBOQS_VER
            if [ -d "${GRA_DIR}" ]; then
                echo "${LIBOQS_VER}" > ./"${GRA_DIR}"/liboqs_ver.log
            else
                echo "${LIBOQS_VER}" > ./liboqs_ver.log
            fi
            # 0.10.1
            # liboqs_ver_nospace="liboqs${LIBOQS_VER}"
            # liboqs0.10.1
        fi
    fi
    # "OpenSSL3.3.1" or "OpenSSL3.3.1 liboqs0.10.0"
    #OPENSSL_INFO="${openssl_ver_nospace} ${liboqs_ver_nospace}"
}
