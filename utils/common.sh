#!/usr/bin/env bash
# Common utilities for plot_openssl*.sh .
#
# This file is part of https://github.com/KazKobara/plot_openssl_speed
# Copyright (C) 2025 National Institute of Advanced Industrial Science and Technology (AIST). All Rights Reserved.

set -e
# set -x

### Params ###
# shellcheck disable=SC2034  # used in plot_openssl*.sh
VER=1.3
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
    # TODO: test realpath and then determine if it requires the given path and file.
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
        # Listing up all the post-quantum algorithms that are not hybrid with
        # classic ones whose names include '_' except
        # X25519MLKEM768 and SecP256r1MLKEM768 for at least
        # openssl-3.4.0-oqsprovider0.7.0-liboqs0.11.0.
        # IFS=" " read -r -a arr_tmp <<< "$(${OPENSSL} list -"${algorithm_type}"-algorithms -provider oqsprovider 2>/dev/null | awk '$1 ~ /(X25519|X448|Sec)/{ next } /^[^_]+ @ oqsprovider$/ {print $1}' | sort -V | awk '{printf "%s ",$1}')"
        # To support the name of OV (and UOV) that includes '_', such as 'OV_I*'
        IFS=" " read -r -a arr_tmp <<< "$(${OPENSSL} list -"${algorithm_type}"-algorithms -provider oqsprovider 2>/dev/null | awk '$1 ~ /(X25519|X448|Sec)/{ next } /^([^_]+|[ ]*OV_I.*) @ oqsprovider$/ {print $1}' | sort -V | awk '{printf "%s ",$1}')"
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


##
# @brief        Set OPENSSL_VER_NOSPACE using ${OPENSSL} command.
# @param[in]    global OPENSSL : openssl command
# @param[in]    global OPENSSL_VER : string
# @param[out]   global OPENSSL_VER_NOSPACE : string for graph title
openssl_ver_nospace_from_command () {
    local tmp
    # get OpenSSL FIPS Provider version "OpenSSL3.1.2" from:
:<<'# COMMENT_EOF'
        Providers:
        base
            name: OpenSSL Base Provider
            version: 3.5.0
            status: active
        fips
            name: OpenSSL FIPS Provider
            version: 3.1.2
            status: active
# COMMENT_EOF
    # NOTE:
    #   For MinGW, $1=="fips" does not work due to the carriage return code after it.
    # tmp=$(${OPENSSL} list -providers | awk '$1=="fips" {getline; printf "%s",$2; getline; print $2}')
    tmp=$(${OPENSSL} list -providers 2>/dev/null | awk '$1 ~ "fips" {getline; printf "%s",$2; getline; print $2}' | tr -d '\r\n')
    if [ -n "${tmp}" ]; then
        # fips provider
        OPENSSL_VER_NOSPACE="${tmp}FIPS"
    else
        # no fips provider
        if [ -z "${OPENSSL_VER}" ]; then
            OPENSSL_VER=$(${OPENSSL} version)
        fi
        OPENSSL_VER_NOSPACE="$(echo "${OPENSSL_VER}" | awk '{print $1 $2}')"
    fi
    export OPENSSL_VER_NOSPACE
}
