#!/usr/bin/env bash

# This file is part of https://github.com/KazKobara/plot_openssl_speed
# Copyright (C) 2024 National Institute of Advanced Industrial Science and Technology (AIST). All Rights Reserved.
set -e
# set -x

. ../../utils/common.sh

### functions ###

##
# @brief        Set oqsprovider.{so,dylin} and openssl.cnf under .local
# @details      Against the error of "speed: Unknown algorithm <oqs algorithm>",
#               run this in the '${TMP}/<openssl-type>' dir and 
#               right above the '.local' dir.
set_oqsprovider_to_dot_local () {
    (
        cd .local/${DOT_LOCAL_LIB}/ossl-modules/
        if [ ! -s ./oqsprovider."${SO}" ]; then
            ln -s ../../../_build/${DOT_LOCAL_LIB}/oqsprovider."${SO}" .
        fi
    )
    (
        cd .local/ssl/ && {
            if grep -E "^[^#].*oqsprovider" openssl.cnf >/dev/null 2>&1 ; then
                echo "Info: check if 'activate = 1' in the oqsprovider section"
                echo "      though '.local/ssl/openssl.cnf' includes 'oqsprovider'."
            else
                mv -f openssl.cnf openssl.cnf.bk;
                ln -s ../../scripts/openssl-ca.cnf ./openssl.cnf;
            fi
        }
    )
}


##
# @brief        Set oqsprovider.{so,dylin} for the openssl in the PATH
set_oqsprovider_to_path () {
    local openssl_dir openssl_modules
    OPENSSL=openssl
    # openssl_dir="$($OPENSSL version -a | awk '/OPENSSLDIR:/ {printf "%s",$2}' | sed -e 's/"//g')"
    # openssl_modules="$($OPENSSL version -a | awk '/MODULESDIR:/ {printf "%s",$2}' | sed -e 's/"//g')"
    openssl_dir="$($OPENSSL version -a | awk '/OPENSSLDIR:/ {printf "%s",substr($2,2,length($2)-2);}')"
    openssl_modules="$($OPENSSL version -a | awk '/MODULESDIR:/ {printf "%s",substr($2,2,length($2)-2);}')"
    if [ -n "${openssl_modules}" ] && [ ! -s "${openssl_modules}/oqsprovider.$SO" ]; then
        echo "'openssl' in the PATH supports 'provider modules' but no oqsprovider"
        echo "in the module dir '${openssl_modules}'."
        echo
        echo "Do you want to copy ./_build/${DOT_LOCAL_LIB}/oqsprovider.${SO} to there?"
        read -p "[y/n]:" ans
        if [ "$ans" == "y" ]; then
            cp -fp ./_build/${DOT_LOCAL_LIB}/oqsprovider.${SO} "${openssl_modules}/."
            echo
            echo "Add the following lines in the '${openssl_dir}/openssl.cnf':"
            echo
            echo "In the [provider_sect]:"
            echo "oqsprovider = oqsprovider_sect"
            echo "oqsprovider2 = oqsprovider2_sect"
            echo
            echo "In the [default_sect]:"
            echo "# activate = 1"
            echo "activate = 1"
            echo
            echo "Outside of the [provider_sect]:"
            echo "[oqsprovider_sect]"
            echo "activate = 1"
            echo "[oqsprovider2_sect]"
            echo "activate = 1"
            echo
        fi
    fi
}


### main ###
set_oqsprovider_to_dot_local
set_oqsprovider_to_path
